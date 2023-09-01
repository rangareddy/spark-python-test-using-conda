#!/bin/bash

export DATA_DIR=${DATA_DIR:-"/opt/data"}
export INPUT_SCRIPT_NAME=$(basename "$0")			        # Input file name
export LOG_FILE_NAME="${INPUT_SCRIPT_NAME%.sh}"  	        # Remove the '.sh' extension
export OUTPUT_LOG_FILE="${DATA_DIR}/${LOG_FILE_NAME}.log"   # Output Log file

if [ -f "$OUTPUT_LOG_FILE" ]; then 
    rm -rf "$OUTPUT_LOG_FILE"
fi 

touch "$OUTPUT_LOG_FILE"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp][$level] $message"
    echo "[$timestamp][$level] $message" >> "$OUTPUT_LOG_FILE"
}

log_debug() {
    log "INFO" "$@"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_info "Data Directory Path: $DATA_DIR "

# Define Spark2 versions to test
export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

# Define Spark3 versions to test
export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

# Define Spark versions to test
export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")
#export SPARK_VERSIONS=("2.3.0")
log_info "Spark Versions: ${SPARK_VERSIONS[@]}"

export PYTHON_VERSIONS=("2.7" "3.4" "3.5" "3.6" "3.7" "3.9" "3.10" "3.11")
#export PYTHON_VERSIONS=("2.7")
log_info "Python Versions: ${PYTHON_VERSIONS[@]}"

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export MODULES_TO_TEST_ARRY=("pyspark-core" "pyspark-sql" "pyspark-streaming"  "pyspark-mllib" "pyspark-ml")
message="PySpark Unit Testing Modules : ${MODULES_TO_TEST_ARRY[@]}"
log_info "$message"

export PYSPARK_EXAMPLES_DIR="/opt/pyspark_examples"
export SPARK_APP_LOGS_PATH="$DATA_DIR/spark_app_logs"
mkdir -p "$SPARK_APP_LOGS_PATH" || exit

export SPARK_INSTALL_DIR="${DATA_DIR}/spark"

# Creating the conda environment
create_conda_env() {
    CONDA_ENV_NAME="$1"
    if ! conda env list | grep -q "$CONDA_ENV_NAME" ; then
        log_info "Creating the Python $CONDA_ENV_NAME environment..."
        conda create -y --name $CONDA_ENV_NAME python=$python_version > /dev/null
        if [ $? -eq 0 ]; then
            log_info "Python environment $CONDA_ENV_NAME created successfully"
        else
            log_error "Python environment $CONDA_ENV_NAME creation failed"
        fi
    fi
}

# Install Python Dependencies
install_python_dependencies() {
    python_version="$1"
    log_debug "Installing the python dependencies"
    #pip install -r "$SPARK_HOME"/dev/requirements.txt
    pip install -U pip setuptools wheel requests
    if [[ "$python_version" == "2."* ]]; then
        pip install -U cython "numpy==1.10.4" "pyarrow>=0.8.0,<0.10.0" "pandas >= 0.19.2" scikit-learn matplotlib
    else
        pip install -U numpy pyarrow pandas scikit-learn scipy matplotlib
    fi
    log_info "Display the list of Python ${python_version} Packages Installed"
    echo "$(pip list)"
}

# Download and build the Spark Souce code
download_and_build_spark_source_code() {
    local spark_version="$1"

    if [ ! -d "$SPARK_HOME" ]; then
        log_debug "Download the Spark version $spark_version source code"
        git -c advice.detachedHead=false clone --branch "v$spark_version" \
            --single-branch https://github.com/apache/spark.git "$SPARK_HOME"
    fi

    local SPARK_BUILD_CMD_OUPUT_FILE="${SPARK_HOME}/spark_build_output.log"
    local SPARK_BUILD_STATUS_FILE="${SPARK_HOME}/spark_build_status"
    IS_BUILD_SOURCE_CODE="Yes"

    if [ -f "${SPARK_BUILD_STATUS_FILE}" ] ; then
        if grep -q "BUILD SUCCESS" "${SPARK_BUILD_STATUS_FILE}" ; then
            IS_BUILD_SOURCE_CODE="No"
        fi
    fi 

    if [ "$IS_BUILD_SOURCE_CODE" == "Yes" ]; then 
        log_debug "Building the Spark version $spark_version source code"
        BUILD_ARGS=""
        if [[ "$spark_version" == 2.* ]]; then
            BUILD_ARGS="-Pflume -Pkafka-0-8"
        fi
        cd ${SPARK_HOME}
        ./build/mvn -DskipTests clean package -Pyarn -Phive -Phive-thriftserver ${BUILD_ARGS} > "${SPARK_BUILD_CMD_OUPUT_FILE}"
        if grep -q "BUILD SUCCESS" "${SPARK_BUILD_CMD_OUPUT_FILE}" ; then
            log_info "Spark version $spark_version source code build success"
            echo "BUILD SUCCESS" > $SPARK_BUILD_STATUS_FILE
            rm -rf "${SPARK_BUILD_CMD_OUPUT_FILE}"
        else
            echo "BUILD FAILED" > "${SPARK_BUILD_STATUS_FILE}"
            log_error "Spark version ${spark_version} source code build failed"
            exit 1
        fi
    else
        log_warn "Spark version ${spark_version} source code has been built"
    fi
}

# Running the Spark Submit Application
run_spark_submit_app() {
    local spark_submit_example_file="$1"
    local spark_submit_example_py_file="$2"
    if [ ! -f "$spark_submit_example_file" ]; then
        "${SPARK_HOME}"/bin/spark-submit --master "local[*]" \
            "$PYSPARK_EXAMPLES_DIR"/"$spark_submit_example_py_file" &> "$spark_submit_example_file"
    fi
}

# Running the Spark Submit Applications tests
run_spark_submit_apps_tests() {

    local spark_submit_app_tests_dir="$1"
    local spark_minified_version="$2"
    local python_minified_version="$3"
    local spark_submit_file_prefix="${spark_submit_app_tests_dir}/Spark_Submit_${spark_minified_version}_${python_minified_version}"

    spark_submit_udf_example_file="${spark_submit_file_prefix}_UDF_Example.log"
    run_spark_submit_app "$spark_submit_udf_example_file" "pyspark_udf_example.py"

    spark_submit_pandas_example_file="${spark_submit_file_prefix}_Pandas_Example.log"
    run_spark_submit_app "$spark_submit_pandas_example_file" "pyspark_pandas_example.py"

    spark_submit_numpy_example_file="${spark_submit_file_prefix}_Numpy_Example.log"
    run_spark_submit_app "$spark_submit_numpy_example_file" "pyspark_numpy_example.py"

    # Deleting unwanted files
    rm -rf $SPARK_HOME/derby.log
    rm -rf $SPARK_HOME/spark-warehouse
}

# Running the PySpark Modules tests
run_pyspark_modules_unit_tests() {
    
    local pyspark_unit_tests_res_dir="$1"
    local spark_version="$2"
    local spark_min_version="$3"
    local python_version="$4"
    local python_min_version="$5"
    local installed_python_dependencies="No"

    log_info "***** Running PySpark ${spark_version} Unit tests with Python version ${python_version} *****"
    for modules_to_test in "${MODULES_TO_TEST_ARRY[@]}"; do
        RUN_TESTS_OUTPUT_FILE="${pyspark_unit_tests_res_dir}/${python_min_version}-${modules_to_test}"
        is_run_module_test_case="No"
        if [ ! -f "$RUN_TESTS_OUTPUT_FILE" ]; then 
            is_run_module_test_case="Yes"
        else
            TEST_FAILURE_STATUS=""
            if [ -f "$$RUN_TESTS_OUTPUT_FILE" ]; then 
                TEST_FAILURE_STATUS=$(awk '/Traceback \(most recent call last\)/,/TypeError:/' "$RUN_TESTS_OUTPUT_FILE")
            fi 
            if [ -n "$TEST_FAILURE_STATUS" ]; then
                log_warn "Spark ${spark_version} Python ${python_version} are not supported for module ${modules_to_test}"
            elif grep -q "FAILED (failures=\|Had test failures in" "$RUN_TESTS_OUTPUT_FILE" ; then
                log_warn "Spark ${spark_version} Python ${python_version} Unit test(s) are failed module ${modules_to_test}." \
                    "Check the failure test(s) in $RUN_TESTS_OUTPUT_FILE file"
            elif grep -q "Tests passed in" "$RUN_TESTS_OUTPUT_FILE" ; then
                log_info "Spark version ${spark_version} Python version ${python_version} Module ${modules_to_test} test cases are already successful"
            else
                is_run_module_test_case="Yes"
            fi
        fi

        if [ "$is_run_module_test_case" == "Yes" ]; then 
            if [ "$installed_python_dependencies" == "No" ]; then 
                install_python_dependencies "$python_version" 
                installed_python_dependencies="yes"
            fi
            log_debug "Run the Spark version ${spark_version} Python version ${python_version} Module ${modules_to_test} test cases"
            module_test_start_msg="[$(date +'%Y-%m-%d %H:%M:%S')] Running the Pyspark ${spark_version}:${python_version} unit tests for modules ${modules_to_test} started"
            echo "$module_test_start_msg" > "${RUN_TESTS_OUTPUT_FILE}"
            "$SPARK_HOME"/python/run-tests --modules "${modules_to_test}" >> "${RUN_TESTS_OUTPUT_FILE}"
            module_test_end_msg="[$(date +'%Y-%m-%d %H:%M:%S')] Running the Pyspark ${spark_version}:${python_version} unit tests for modules ${modules_to_test} completed"
            echo "$module_test_end_msg" >> "${RUN_TESTS_OUTPUT_FILE}"
        fi
    done
    log_info "***** Finished PySpark ${spark_version} Unit tests with Python version ${python_version} *****"
}                

# Test the Pyspark with the different Python versions
run_pyspark_tests() {
    for python_version in "${PYTHON_VERSIONS[@]}"; do

        local python_min_version=$(echo "$python_version" | tr -d .)
        local CONDA_ENV_NAME="my_env_$(echo "$python_version" | sed 's/\./_/g')"

        create_conda_env "$CONDA_ENV_NAME"

        # If conda environment exists then run the tests
        if conda env list | grep -q "$CONDA_ENV_NAME" ; then

            # Activate the created environment
            source /opt/conda/etc/profile.d/conda.sh
            conda activate "$CONDA_ENV_NAME"
            
            export PYSPARK_PYTHON=$(which python)
            export PYSPARK_DRIVER_PYTHON=$(which python)

            for spark_version in "${SPARK_VERSIONS[@]}"; do
                log_info "===== Running the Spark version ${spark_version} test cases ====="

                local spark_minified_version=$(echo "${spark_version}" | tr -d .)
                export SPARK_HOME="${SPARK_INSTALL_DIR}/spark_${spark_minified_version}"
                download_and_build_spark_source_code "${spark_version}"

                local logs_output_dir="${SPARK_APP_LOGS_PATH}/${spark_minified_version}"
                local pyspark_unit_tests_res_dir="$logs_output_dir/spark_python_unit_test_logs"
                local spark_submit_app_tests_dir="$logs_output_dir/spark_submit_app_logs"
                mkdir -p "$pyspark_unit_tests_res_dir" "$spark_submit_app_tests_dir" || exit

                # Running the PySpark Modules tests
                run_pyspark_modules_unit_tests "$pyspark_unit_tests_res_dir" "$spark_version" "$spark_minified_version" "$python_version" "$python_min_version"

                # Running the Spark Submit Applications tests
                run_spark_submit_apps_tests "$spark_submit_app_tests_dir" "$spark_minified_version" "$python_min_version"
                
                log_info "===== Finished the Spark version ${spark_version} test cases ====="
            done # spark versions
            conda deactivate # Deactivate the conda environment
            conda-env remove -n ${CONDA_ENV_NAME}
        else 
            log_warn "Environment ${CONDA_ENV_NAME} not created"
        fi
    done # python versions
}

log_info "Running the Spark Python Tests started"
run_pyspark_tests
log_info "Running the Spark Python Tests completed"