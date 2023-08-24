#!/bin/bash

script_name=$(basename "$0")
echo "Running the script $script_name"

export DATA_DIR=${DATA_DIR:-"/opt/data"}
echo "Data Directory Path: $DATA_DIR"

# Define Spark2 versions to test
export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

# Define Spark3 versions to test
export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

# Define Spark versions to test
export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")

for spark_version in "${SPARK_VERSIONS[@]}"; do
    echo "Check and download the Spark version $spark_version source code"
    spark_min_version=$(echo "${spark_version}" | tr -d .)
    export SPARK_HOME="${DATA_DIR}/spark/spark_${spark_min_version}"
    if [ ! -d "$SPARK_HOME" ]; then
        echo "Downloading the Spark version $spark_version source code"
        git -c advice.detachedHead=false clone --branch "v$spark_version" \
            --single-branch https://github.com/apache/spark.git "$SPARK_HOME"
        if [ $? -eq 0 ]; then
            echo "Spark version $spark_version source code downloaded successfully"
        else
            echo "Spark version $spark_version source code download failed"
            exit 1
        fi
    fi

    SPARK_BUILD_CMD_OUPUT_FILE="${SPARK_HOME}/spark_build_output.log"
    SPARK_BUILD_SUCCESS_STATUS_FILE="${SPARK_HOME}/spark_build_status.log"
    if test ! -f "${SPARK_BUILD_SUCCESS_STATUS_FILE}" ; then
        echo "Building the Spark version $spark_version source code"
        BUILD_ARGS=""
        if [[ "$spark_version" == 2.* ]]; then
            BUILD_ARGS="-Pflume -Pkafka-0-8"
        fi
        cd ${SPARK_HOME}
        ./build/mvn -DskipTests clean package -Pyarn -Phive -Phive-thriftserver ${BUILD_ARGS} > "${SPARK_BUILD_CMD_OUPUT_FILE}"
        if grep -q "BUILD SUCCESS" "${SPARK_BUILD_CMD_OUPUT_FILE}" ; then
            echo "Spark version $spark_version source code build success"
            touch "${SPARK_BUILD_SUCCESS_STATUS_FILE}"
            rm -rf "${SPARK_BUILD_CMD_OUPUT_FILE}"
        else
            echo "Spark version ${spark_version} source code build failed"
            exit 1
        fi
    else 
        echo "Spark version ${spark_version} source code has been built"
    fi 
done

echo "Finished script $script_name"