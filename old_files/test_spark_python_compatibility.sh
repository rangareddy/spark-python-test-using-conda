#!/bin/bash

# Define Spark2 versions to test
export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

# Define Spark3 versions to test
export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

# Define Spark versions to test
export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")

# Define Python versions to test
export PYTHON_VERSIONS=("2.7" "3.4" "3.5" "3.6" "3.7" "3.8" "3.9" "3.10" "3.11" "3.12")

export SPARK_APP_LOGS_PATH="$DATA_DIR/spark_app_logs"
mkdir -p $SPARK_APP_LOGS_PATH

export PYSPARK_TEST_RESULT="$SPARK_APP_LOGS_PATH/spark-python-test-result.md"
export PYSPARK_TEST_ERRORS="$SPARK_APP_LOGS_PATH/spark-python-test-errors.md"
export CONDA_HOME="/opt/conda"

# Creating the environments
create_conda_environment() {
    for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"; do
        CONDA_ENV_NAME="my_env_$(echo "$PYTHON_VERSION" | sed 's/\./_/g')"
        if [[ ! -d "$CONDA_HOME/envs/$CONDA_ENV_NAME" ]]; then
            echo "Creating the $CONDA_ENV_NAME environment..."
            echo "======================================================="
            conda create -y --name $CONDA_ENV_NAME python=$PYTHON_VERSION 2>&1
            if [ $? -eq 0 ]; then
                echo "Environment <$CONDA_ENV_NAME> created successfully"
            else
                echo "Environment <$CONDA_ENV_NAME> creation failed."
            fi
            echo ""
        fi
    done
}
echo ""
echo "Creating the environments"
create_conda_environment

# Test the Pyspark with the different Python versions
run_pyspark_tests() {
    echo "# Spark Python Integration Test Result Exceptions" >> "$PYSPARK_TEST_ERRORS"
    echo "" >> "$PYSPARK_TEST_ERRORS"

    echo "| Spark Version 	| Python Version 	| Python Release Version 	| Supported 	|" >> $PYSPARK_TEST_RESULT
    echo "| ---------------	|------------------	|--------------------------	|-------------- |" >> $PYSPARK_TEST_RESULT

    # Loop through the Spark versions
    for spark_version in "${SPARK_VERSIONS[@]}"; do

        # Get the Spark minified version
        spark_min_version=$(echo "${spark_version}" | tr -d .)
        spark_major_version=${spark_version:0:1}
        logs_output_dir=$SPARK_APP_LOGS_PATH/$spark_major_version/$spark_min_version
        mkdir -p $logs_output_dir && cd $logs_output_dir

        for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"; do
            CONDA_ENV_NAME="my_env_$(echo "$PYTHON_VERSION" | sed 's/\./_/g')"
            if [[ -d "$CONDA_HOME/envs/$CONDA_ENV_NAME" ]]; then
                source /opt/conda/etc/profile.d/conda.sh

                # Activate the created environment
                conda activate $CONDA_ENV_NAME

                local python_release_version=$(python -V 2>&1 | awk '{print $2}')
                local python_min_version=$(echo $python_release_version | tr -d .)

                # Install the Pyspark
                pip install pyspark==${spark_version} -v

                # Submit the Spark job
                echo "Running the Spark job using Spark version ${spark_version} and Python version $PYTHON_VERSION"
                test_result_ouputfile="PySpark_${spark_min_version}_Test_With_Python_${python_min_version}.log"
                spark-submit --master "local[*]" /opt/pyspark_udf_example.py &> $test_result_ouputfile
                if cat $test_result_ouputfile | grep 'Successfully stopped SparkContext' ; then 
                    test_result="Yes"
                else
                    test_result="No"
                    test_failed_output=$(cat $test_result_ouputfile | grep -vE 'INFO|WARN')
                    echo "## Spark Version: $spark_version, Python Version: $PYTHON_VERSION, Python Release Version: $python_release_version" >> "$PYSPARK_TEST_ERRORS"
                    echo "" >> "$PYSPARK_TEST_ERRORS"
                    echo "\`\`\`python" >> "$PYSPARK_TEST_ERRORS"
                    echo "$test_failed_output" >> "$PYSPARK_TEST_ERRORS"
                    echo "\`\`\`" >> "$PYSPARK_TEST_ERRORS"
                    echo "" >> "$PYSPARK_TEST_ERRORS"
                fi
                echo "| $spark_version	| $PYTHON_VERSION	| $python_release_version | $test_result |" >> $PYSPARK_TEST_RESULT

                # Uninstall the Pyspark
                pip uninstall -y pyspark==${spark_version}

                # Deactivate the conda environment
                conda deactivate
            else
                echo "Environment <$CONDA_ENV_NAME> not created ....."
            fi
        done # python versions
    done # spark versions
}

echo ""
echo "Running the Spark Python Tests started"
run_pyspark_tests
echo "Running the Spark Python Tests completed"