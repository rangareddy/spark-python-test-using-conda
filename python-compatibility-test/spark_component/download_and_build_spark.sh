#!/bin/bash

### Description   : This script is used to download and build the Spark source code
### Author        : Ranga Reddy <rangareddy.avula@gmail.com>
### Date          : 03-Sep-2023
### Version       : 1.0.0

# Include the log utility script
source /opt/log_util_file.sh

script_name=$(basename "$0")
log_debug "Running the script $script_name"

export DATA_DIR=${DATA_DIR:-"/opt/data"}
export BUILD_TOOL=${BUILD_TOOL:-"mvn"}

# Define Spark2 versions to test
export SPARK2_VERSIONS=("2.3.0" "2.3.1" "2.3.2" "2.3.3" "2.3.4" "2.4.0" "2.4.1" "2.4.2" "2.4.3" "2.4.4" "2.4.5" "2.4.6" "2.4.7" "2.4.8")

# Define Spark3 versions to test
export SPARK3_VERSIONS=("3.0.0" "3.0.1" "3.0.2" "3.0.3" "3.1.1" "3.1.2" "3.1.3" "3.2.0" "3.2.1" "3.2.2" "3.2.3" "3.3.0" "3.3.1" "3.3.2" "3.4.0" "3.4.1")

# Define Spark versions to test
export SPARK_VERSIONS=("${SPARK2_VERSIONS[@]}" "${SPARK3_VERSIONS[@]}")

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
            #exit 1
        fi
    else
        log_warn "Spark version ${spark_version} source code has been built"
    fi
}

export MAVEN_OPTS="-Xss64m -Xmx2g -XX:+UseCodeCacheFlushing -XX:ReservedCodeCacheSize=2g"

for spark_version in "${SPARK_VERSIONS[@]}"; do
    echo "Check and download the Spark version $spark_version source code"
    spark_min_version=$(echo "${spark_version}" | tr -d .)
    export SPARK_HOME="${DATA_DIR}/spark/spark_${spark_min_version}"
    download_and_build_spark_source_code "$spark_version"
done

log_info "Finished the script $script_name"