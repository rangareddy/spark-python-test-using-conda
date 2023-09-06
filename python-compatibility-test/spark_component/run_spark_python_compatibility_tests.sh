#!/bin/bash

if [ "$COUNTER" -eq 1 ]; then 
    # Download and build the Spark source code
    bash /opt/download_and_build_spark.sh
fi

# Include the log utility script
source /opt/log_util_file.sh

# Get the Python version and store it in a variable
export python_version=$(python -V 2>&1 | cut -d " " -f 2 | cut -d "." -f 1,2)
export python_minified_version=$(echo "$python_version" | tr -d .)  
log_info "Testing the Spark Python Compatibility tests for Python version : $python_version"

export PYSPARK_PYTHON=$(which python)
export PYSPARK_DRIVER_PYTHON=$(which python)
export TRUE="true"
export FALSE="false"
export IS_RUN_SPARK_SUBMIT_TESTS="$TRUE"
export IS_RUN_SPARK_UNIT_TESTS="$TRUE"

if [ -z "$SPARK_VERSIONS" ]; then 
    # Define Spark2 versions to test
    export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

    # Define Spark3 versions to test
    export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

    # Combine Spark2 and Spark3 versions into a single array
    export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")
    log_info "Spark Versions: ${SPARK_VERSIONS[@]}"
fi 

# Disable fork safety for Objective-C
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export PYSPARK_EXAMPLES_DIR="/opt/pyspark_examples"
export SPARK_APP_LOGS_PATH="$DATA_DIR/spark_app_logs"

# Create Spark app logs directory if it doesn't exist
mkdir -p "$SPARK_APP_LOGS_PATH" || exit

# Set Spark installation directory
export SPARK_INSTALL_DIR="${DATA_DIR}/spark"

# Install Python Dependencies
# This function is used to install python dependencies using Python version.
install_python_dependencies() {
    log_debug "Installing the python version $python_version dependencies"
    # Install required Python packages
    pip install -U pip setuptools wheel requests --ignore-installed certifi
    if [[ "$python_version" == "2."* ]]; then
        pip install -U cython "numpy>=1.12.0" "pyarrow>=0.8.0,<0.10.0" "pandas >= 0.19.2" scikit-learn matplotlib
    else
        pip install -U numpy pyarrow pandas scikit-learn scipy matplotlib
    fi
    #pip install -r "$SPARK_HOME"/dev/requirements.txt
    log_info "Display the list of Python ${python_version} Packages Installed"
    log_info "$(pip list)"
}

# Running the Spark Submit Application
# This function is used to submit the spark application based on python file.
run_spark_submit_app() {
    local spark_submit_example_file="$1"
    local spark_submit_example_py_file="$2"
    if [ ! -f "$spark_submit_example_file" ]; then
        "${SPARK_HOME}"/bin/spark-submit --master "local[2]" --conf spark.eventLog.enabled=false --conf spark.ui.enabled=false \
            "$PYSPARK_EXAMPLES_DIR"/"$spark_submit_example_py_file" &> "$spark_submit_example_file"
    fi
}

# Running the Spark Submit Application(s) to tests
# This function is used to submit the all kinds of spark applications 
run_spark_submit_apps_tests() {
    local spark_submit_app_tests_dir="$1"
    local spark_minified_version="$2"
    local spark_submit_file_prefix="${spark_submit_app_tests_dir}/Spark_Submit_${spark_minified_version}_${python_minified_version}"

    spark_submit_udf_example_file="${spark_submit_file_prefix}_UDF_Example.log"
    run_spark_submit_app "$spark_submit_udf_example_file" "pyspark_udf_example.py" &

    spark_submit_pandas_example_file="${spark_submit_file_prefix}_Pandas_Example.log"
    run_spark_submit_app "$spark_submit_pandas_example_file" "pyspark_pandas_example.py" &

    spark_submit_numpy_example_file="${spark_submit_file_prefix}_Numpy_Example.log"
    run_spark_submit_app "$spark_submit_numpy_example_file" "pyspark_numpy_example.py" &
    wait
}

# Running the PySpark Modules tests
run_pyspark_modules_unit_tests() {
    local pyspark_unit_tests_res_dir="$1"
    local spark_version="$2"
    local spark_min_version="$3"
    log_debug "Running PySpark ${spark_version} Unit tests with Python version ${python_version}"

    # PySpark Modules to test
    results=$(python "$PYSPARK_EXAMPLES_DIR/pyspark-modules.py" "$SPARK_HOME")
    export MODULES_TO_TEST_ARRY=($results)
    #export MODULES_TO_TEST_ARRY=$(python "$PYSPARK_EXAMPLES_DIR/pyspark-modules.py" "$SPARK_HOME")
    message="PySpark Unit Testing Modules : ${MODULES_TO_TEST_ARRY[@]}"
    log_info "$message"

    for modules_to_test in "${MODULES_TO_TEST_ARRY[@]}"; do
        RUN_TESTS_OUTPUT_FILE=$(ls ${pyspark_unit_tests_res_dir}/${python_minified_version}*-${modules_to_test} 2> /dev/null | head -1)
        is_run_module_test_case="$FALSE"
        if [ ! -f "$RUN_TESTS_OUTPUT_FILE" ]; then 
            is_run_module_test_case="$TRUE"
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
                is_run_module_test_case="$TRUE"
            fi
        fi
        if [ "$is_run_module_test_case" == "$TRUE" ]; then
            if [ -z "$RUN_TESTS_OUTPUT_FILE" ]; then
                RUN_TESTS_OUTPUT_FILE="${pyspark_unit_tests_res_dir}/${python_minified_version}-${modules_to_test}"
            fi 
            log_debug "Run the Spark version ${spark_version} Python version ${python_version} Module ${modules_to_test} test cases"
            module_test_start_msg="[$(date +'%Y-%m-%d %H:%M:%S')] Running the Pyspark ${spark_version}:${python_version} unit tests for modules ${modules_to_test} started"
            echo "$module_test_start_msg" > "${RUN_TESTS_OUTPUT_FILE}"
            "$SPARK_HOME"/python/run-tests --modules "${modules_to_test}" --python-executables=python >> "${RUN_TESTS_OUTPUT_FILE}"
            module_test_end_msg="[$(date +'%Y-%m-%d %H:%M:%S')] Running the Pyspark ${spark_version}:${python_version} unit tests for modules ${modules_to_test} completed"
            echo "$module_test_end_msg" >> "${RUN_TESTS_OUTPUT_FILE}"
        fi
    done
    log_info "Finished PySpark ${spark_version} Unit tests with Python version ${python_version}"
}

# Run the Spark Python Tests with multiple spark versions
run_spark_python_tests() {
    log_info "Running the Spark Python Tests started"

    for ((i=${#SPARK_VERSIONS[@]}-1; i>=0; i--)); do
        spark_version=${SPARK_VERSIONS[$i]}
        log_info "Running the Spark version ${spark_version} test cases"
        local spark_minified_version=$(echo "${spark_version}" | tr -d .)
        export SPARK_HOME="${SPARK_INSTALL_DIR}/spark_${spark_minified_version}"
        if [ -f "$SPARK_HOME/spark_build_status" ]; then
            if grep -q "BUILD SUCCESS" "$SPARK_HOME/spark_build_status" ; then
                local logs_output_dir="${SPARK_APP_LOGS_PATH}/${spark_minified_version}"
                local pyspark_unit_tests_res_dir="$logs_output_dir/spark_python_unit_test_logs"
                local spark_submit_app_tests_dir="$logs_output_dir/spark_submit_app_logs"
                mkdir -p "$pyspark_unit_tests_res_dir" "$spark_submit_app_tests_dir" || exit

                # Running the PySpark Modules tests
                if [ "$IS_RUN_SPARK_UNIT_TESTS" == "$TRUE" ]; then
                    run_pyspark_modules_unit_tests "$pyspark_unit_tests_res_dir" "$spark_version" "$spark_minified_version"
                fi 

                # Running the Spark Submit Applications tests
                if [ "$IS_RUN_SPARK_SUBMIT_TESTS" == "$TRUE" ]; then
                    run_spark_submit_apps_tests "$spark_submit_app_tests_dir" "$spark_minified_version"
                fi 
                
                # Deleting unwanted files
                rm -rf $SPARK_HOME/derby.log 2> /dev/null
                rm -rf $SPARK_HOME/spark-warehouse 2> /dev/null
                rm -rf $SPARK_HOME/hs_err_pid*.log 2> /dev/null
            fi 
        else
            log_warn "Spark Source code for Spark version ${spark_version} build is failed"
        fi
        log_info "Finished the Spark version ${spark_version} test cases"
    done # spark versions
    log_info "Running the Spark Python Tests completed"
}

install_python_dependencies
run_spark_python_tests
