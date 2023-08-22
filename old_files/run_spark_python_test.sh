#!/bin/bash

# Create a temp file to track the health check status
printf "Health Check started\n" > "/tmp/healthcheck.txt"

# Define Spark2 versions to test
export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

# Define Spark3 versions to test
export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

# Define Spark versions to test
export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")

# Define Python versions to test
export PYTHON_VERSIONS=("2.7" "3.4" "3.5" "3.6" "3.7" "3.8" "3.9" "3.10" "3.11" "3.12")

export SPARK_APP_LOGS_PATH="/opt/spark_app_logs"
export SPARK_BINARIES_PATH="/opt/spark_binaries"
mkdir -p $SPARK_APP_LOGS_PATH && mkdir -p $SPARK_BINARIES_PATH

export PYSPARK_TEST_RESULT="$SPARK_APP_LOGS_PATH/spark-python-test-result.md"
export PYSPARK_TEST_ERRORS="$SPARK_APP_LOGS_PATH/spark-python-test-errors.md"

# Set the SPARK_HOME environment variable to the location of Spark
export SPARK_HOME="/opt/spark"

# Add Spark's bin directory to the PATH environment variable
export PATH=$PATH:$SPARK_HOME/bin

delete_file_if_exists() {
    local file_path="$1"
    if [ -f "$file_path" ]; then 
        rm -rf "$file_path" 
    fi
}

# Function to download and extract the Spark binaries for a given version
download_spark() {
    local spark_version=$1

    # Set the Hadoop versions based on the Spark version
    if [[ $spark_version > "3.3" ]]; then
        hadoop_version=3
    elif [[ "$spark_version" == 3* ]]; then
        hadoop_version=3.2
    else
        hadoop_version=2.7
    fi

    local spark_tar_file="spark-$spark_version-bin-hadoop$hadoop_version.tgz"
    local spark_download_path="$SPARK_BINARIES_PATH/$spark_tar_file"

    # Download the Spark binaries if necessary
    if [[ ! -f "$spark_download_path" ]]; then
        spark_download_url="https://archive.apache.org/dist/spark/spark-$spark_version/$spark_tar_file"
        echo "Downloading Spark $spark_version binaries from $spark_download_url ..."
        if ! curl "$spark_download_url" --output "$spark_download_path"; then
            echo "Error: Unable to download the Spark binaries from $spark_download_url"
            exit 1
        fi
    fi

    # Extract the Spark binaries
    if [[ -f "$spark_download_path" ]]; then
        echo "Extracting Spark $spark_version binaries from $spark_download_path ..."
        if ! tar -xf "$spark_download_path" -C /tmp; then
            echo "Error: Unable to extract the Spark binaries from $spark_download_path"
            exit 1
        fi

        # Remove the existing Spark installation if it exists
        if [[ -d $SPARK_HOME ]]; then
            rm -rf "$SPARK_HOME"
        fi
        mv "/tmp/spark-$spark_version-bin-hadoop$hadoop_version" "$SPARK_HOME"
    fi
    echo "Verifying the Spark version"
    spark_verified_version=$(spark-submit --version | grep '  version')
    echo "Verified Spark version $spark_verified_version"
}

# Run the Pyspark Example(s)
run_pyspark_example() {
    local spark_version=$1
    local spark_min_version=$2
    local python_version=$3
    local python_path=/usr/bin/python$python_version
    local python_release_version=""
    local test_result=""
    if [ -f "$python_path" ]; then
        ln -sf "$python_path" /usr/bin/python
        local python_release_version=$(python -V 2>&1 | awk '{print $2}')
        local python_min_version=$(echo $python_release_version | tr -d .)
        export PYSPARK_PYTHON=$python_path
        test_result_ouputfile="PySpark_${spark_min_version}_Test_With_Python_${python_min_version}.log"
        spark-submit --master "local[*]" /opt/pyspark_udf_example.py &> $test_result_ouputfile
        if cat $test_result_ouputfile | grep 'Successfully stopped SparkContext'; then 
            test_result="Yes"
        else
            test_result="No"
            test_failed_output=$(cat $test_result_ouputfile | grep -vE 'INFO|WARN')
            echo "## Spark Version: $spark_version, Python Version: $python_version, Python Release Version: $python_release_version" >> "$PYSPARK_TEST_ERRORS"
            echo "" >> "$PYSPARK_TEST_ERRORS"
            echo "\`\`\`python" >> "$PYSPARK_TEST_ERRORS"
            echo "$test_failed_output" >> "$PYSPARK_TEST_ERRORS"
            echo "\`\`\`" >> "$PYSPARK_TEST_ERRORS"
            echo "" >> "$PYSPARK_TEST_ERRORS"
        fi

        if [[ $python_version =~ ^2\.[6-9]\.?[0-9]* ]] || [[ $python_version =~ ^3\.[0-6]\.?[0-9]* ]]; then
            curl https://bootstrap.pypa.io/pip/$python_version/get-pip.py -o get-pip.py
        else
            curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        fi
        
        python get-pip.py
        python -m pip install --upgrade pip
        pip install pyspark numpy pandas
        spark-submit --master "local[*]" /opt/pyspark_numpy_example.py &> $test_result_ouputfile
        spark-submit --master "local[*]" /opt/pyspark_pandas_example.py &> $test_result_ouputfile
    else 
        echo "Python version $python_version is not installed"
    fi
    echo "| $spark_version	| $python_version	| $python_release_version | $test_result |" >> $PYSPARK_TEST_RESULT
}

delete_file_if_exists "$PYSPARK_TEST_RESULT"
delete_file_if_exists "$PYSPARK_TEST_ERRORS"

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

    # Download the Spark
    download_spark "$spark_version"

    # Test the Pyspark with the different Python versions
    for python_version in "${PYTHON_VERSIONS[@]}"; do
        run_pyspark_example "$spark_version" "$spark_min_version" "$python_version"
    done
    delete_file_if_exists "${logs_output_dir}/spark-warehouse"
done

# Define a cleanup function
cleanup() {
    delete_file_if_exists "/tmp/healthcheck.txt"
}

# Set up a trap to call the cleanup function on exit
trap cleanup EXIT

echo "Spark Python Test successfully finished"