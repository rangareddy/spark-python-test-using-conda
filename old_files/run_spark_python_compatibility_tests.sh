#!/bin/bash

script_name=$(basename "$0")
log_file_name="${script_name%.sh}"  # Remove the '.sh' extension
log_file="${DATA_DIR}/${log_file_name}.log"
if [ -f "$log_file" ]; then 
    rm -rf "$log_file"
fi 
touch "$log_file"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp][$level] $message"
    echo "[$timestamp][$level] $message" >> "$log_file"
}

log_debug() {
    log "INFO" "$1"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

# Define Spark2 versions to test
export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

# Define Spark3 versions to test
export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

# Define Spark versions to test
export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")
export SPARK_VERSIONS=("2.3.0")
export PYTHON_VERSIONS=("3.6" "3.7" "3.9" "3.10")

export SPARK_APP_LOGS_PATH="$DATA_DIR/spark_app_logs"
export PYSPARK_RUN_TESTS_DIR="$SPARK_APP_LOGS_PATH/pyspark-run-tests"

mkdir -p "$SPARK_APP_LOGS_PATH" "$PYSPARK_RUN_TESTS_DIR"

export PYSPARK_TEST_RESULT="$SPARK_APP_LOGS_PATH/spark-python-test-result.md"
export PYSPARK_TEST_ERRORS="$SPARK_APP_LOGS_PATH/spark-python-test-errors.md"

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export MODULES_TO_TEST_ARRY=("pyspark-core" "pyspark-sql" "pyspark-streaming"  "pyspark-mllib" "pyspark-ml")

# Test the Pyspark with the different Python versions
run_pyspark_tests() {
    echo "# Spark Python Integration Test Result Exceptions" > "$PYSPARK_TEST_ERRORS"
    echo "" >> "$PYSPARK_TEST_ERRORS"

    echo "| Spark Version 	| Python Version 	| Python Release Version 	| Supported 	|" > "$PYSPARK_TEST_RESULT"
    echo "| ---------------	|------------------	|--------------------------	|-------------- |" >> "$PYSPARK_TEST_RESULT"

    # Loop through the Spark versions
    for spark_version in "${SPARK_VERSIONS[@]}"; do
        log_info "===== Running the Spark version ${spark_version} test cases ====="
        local spark_min_version=$(echo "${spark_version}" | tr -d .)
        local spark_major_version=${spark_version:0:1}
        local logs_output_dir="${SPARK_APP_LOGS_PATH}/${spark_major_version}/${spark_min_version}"
        mkdir -p "$logs_output_dir" || exit
        export SPARK_HOME="${DATA_DIR}/spark/spark_${spark_min_version}"
        if [ ! -d "$SPARK_HOME" ]; then
            log_debug "Download the Spark version $spark_version source code"
            git clone --branch "v$spark_version" --single-branch https://github.com/apache/spark.git "$SPARK_HOME"
        fi

        SPARK_BUILD_CMD_OUPUT_FILE="${SPARK_HOME}/spark_build_output.log"
        SPARK_BUILD_SUCCESS_STATUS_FILE="${SPARK_HOME}/spark_build_status.log"
        if test ! -f "${SPARK_BUILD_SUCCESS_STATUS_FILE}" ; then
            log_debug "Building the Spark version $spark_version source code"
            BUILD_ARGS=""
            if [[ "$spark_version" == 2.* ]]; then
                BUILD_ARGS="-Pflume -Pkafka-0-8"
            fi
            cd ${SPARK_HOME}
            ./build/mvn -DskipTests clean package -Pyarn -Phive -Phive-thriftserver ${BUILD_ARGS} > "${SPARK_BUILD_CMD_OUPUT_FILE}"
            if grep -q "BUILD SUCCESS" "${SPARK_BUILD_CMD_OUPUT_FILE}" ; then
                log_info "Spark version $spark_version source code build success"
                touch "${SPARK_BUILD_SUCCESS_STATUS_FILE}"
                rm -rf "${SPARK_BUILD_CMD_OUPUT_FILE}"
            else
                log_error "Spark version ${spark_version} source code build failed"
                exit 1
            fi
        else 
            log_warn "Spark version ${spark_version} source code has been built"
        fi 

        export SPARK_TEST_CASES_DIR="${PYSPARK_RUN_TESTS_DIR}/${spark_version}"
        mkdir -p "$SPARK_TEST_CASES_DIR"

        for python_version in "${PYTHON_VERSIONS[@]}"; do
            local CONDA_ENV_NAME="my_env_$(echo "$python_version" | sed 's/\./_/g')"
            local conda_env_result=$(conda env list | grep "$CONDA_ENV_NAME")
            if [ -n "$conda_env_result" ]; then
                
                # Activate the created environment
                source /opt/conda/etc/profile.d/conda.sh
                conda activate "$CONDA_ENV_NAME"

                local python_release_version=$(python -V 2>&1 | awk '{print $2}')
                local python_min_version=$(echo "$python_release_version" | tr -d .)

                # Submit the Spark job
                test_result_ouputfile="${logs_output_dir}/PySpark_${spark_min_version}_Test_With_Python_${python_min_version}.log"
                if [ ! -f $test_result_ouputfile ]; then 
                    log_debug "Running the Spark job using Spark version ${spark_version} and Python version ${python_version}"
                    export PYSPARK_PYTHON=$(which python)
                    export PYSPARK_DRIVER_PYTHON=$(which python)

                    "${SPARK_HOME}"/bin/spark-submit --master "local[*]" /opt/pyspark_udf_example.py &> "$test_result_ouputfile"
                    #"${SPARK_HOME}"/bin/spark-submit --master "local[*]" /opt/pyspark_pandas_example.py &> "$test_result_ouputfile"
                    #"${SPARK_HOME}"/bin/spark-submit --master "local[*]" /opt/pyspark_numpy_example.py &> "$test_result_ouputfile"
                    if grep -q "Successfully stopped SparkContext" "${test_result_ouputfile}"; then
                        test_result="Yes"
                    else
                        test_result="No"
                        test_failed_output=$(cat "$test_result_ouputfile" | grep -vE 'INFO|WARN')
                        echo "## Spark Version: $spark_version, Python Version: $python_version, Python Release Version: $python_release_version" >> "$PYSPARK_TEST_ERRORS"
                        echo "" >> "$PYSPARK_TEST_ERRORS"
                        echo "\`\`\`python" >> "$PYSPARK_TEST_ERRORS"
                        echo "$test_failed_output" >> "$PYSPARK_TEST_ERRORS"
                        echo "\`\`\`" >> "$PYSPARK_TEST_ERRORS"
                        echo "" >> "$PYSPARK_TEST_ERRORS"
                    fi
                    echo "| $spark_version	| $python_version	| $python_release_version | $test_result |" >> "$PYSPARK_TEST_RESULT"
                else
                    log_warn "PySpark UDF example already ran and check the output file $test_result_ouputfile for status"
                fi
                #pip install -r "$SPARK_HOME"/dev/requirements.txt
                #"$SPARK_HOME"/python/run-tests --parallelism 1 --modules "${MODULES_TO_TEST}" > "${RUN_TESTS_OUTPUT_FILE}"
                # Run the Pyspark tests
                log_info "***** Running PySpark ${spark_version} Unit tests with Python version ${python_version} *****"
                for modules_to_test in "${MODULES_TO_TEST_ARRY[@]}"; do
                    RUN_TESTS_OUTPUT_FILE="${SPARK_TEST_CASES_DIR}/${python_min_version}-${modules_to_test}"
                    if [ ! -f "$RUN_TESTS_OUTPUT_FILE" ]; then 
                        log_debug "Run the Spark version ${spark_version} Python version ${python_version} Module ${modules_to_test} test cases"
                        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Run the Pyspark ${spark_version}:${python_version} unit tests for modules ${modules_to_test}" > "${RUN_TESTS_OUTPUT_FILE}"
                        "$SPARK_HOME"/python/run-tests --modules "${modules_to_test}" >> "${RUN_TESTS_OUTPUT_FILE}"
                        TEST_CASE_RESULT="[$(date +'%Y-%m-%d %H:%M:%S')] Pyspark Unit test module ${modules_to_test} completed with status $?"
                        echo "$TEST_CASE_RESULT" >> "${RUN_TESTS_OUTPUT_FILE}"
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
                            log_debug "Rerun the Spark version ${spark_version} Python version ${python_version} Module ${modules_to_test} test cases"
                            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Rerun the Pyspark ${spark_version}:${python_version} unit tests for modules ${modules_to_test}" > "${RUN_TESTS_OUTPUT_FILE}"
                            "$SPARK_HOME"/python/run-tests --modules "${modules_to_test}" >> "${RUN_TESTS_OUTPUT_FILE}"
                            TEST_CASE_RESULT="[$(date +'%Y-%m-%d %H:%M:%S')] Pyspark Unit test module ${modules_to_test} completed with status $?"
                            echo "$TEST_CASE_RESULT" >> "${RUN_TESTS_OUTPUT_FILE}"
                        fi
                    fi 
                done 
                log_info "***** Finished PySpark ${spark_version} Unit tests with Python version ${python_version} *****"
                # Deactivate the conda environment
                conda deactivate
            else
                log_warn "Environment ${CONDA_ENV_NAME} not created"
            fi
        done # python versions
        log_info "===== Finished the Spark version ${spark_version} test cases ====="
    done # spark versions
}

log_info "Running the Spark Python Tests started"
run_pyspark_tests
log_info "Running the Spark Python Tests completed"