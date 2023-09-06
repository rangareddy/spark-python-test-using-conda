#!/bin/bash

export DATA_DIR=${DATA_DIR:-"/opt/data"}
export OUTPUT_LOG_FILE="${DATA_DIR}/python_compatibility_test.log"   # Output Log file

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

export LOG_LEVELS=("DEBUG" "INFO" "WARN" "ERROR")
export DEFAULT_LOG_LEVEL="INFO"
export LOG_LEVEL_INDEX=${LOG_LEVEL_INDEX:-"-1"} 

if [ $LOG_LEVEL_INDEX -eq -1 ]; then 
    for i in "${!LOG_LEVELS[@]}";
    do
        if [[ "${LOG_LEVELS[$i]}" = "${DEFAULT_LOG_LEVEL}" ]];
        then
            LOG_LEVEL_INDEX=$i
            break
        fi
    done
fi

if [ ! -f "$OUTPUT_LOG_FILE" ]; then 
    touch "$OUTPUT_LOG_FILE"
else 
    echo "Running the Script $0 "  >> "$OUTPUT_LOG_FILE"
fi 

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp][$level] $message"
    echo -e "[$timestamp][$level] $message" >> "$OUTPUT_LOG_FILE"
}

log_debug() {
    if [ "0" -ge $LOG_LEVEL_INDEX ]; then
        log "DEBUG" "$@"
    fi 
}

log_info() {
    if [ "1" -ge $LOG_LEVEL_INDEX ]; then
        log "${GREEN}INFO${NC}" "$@"
    fi
}

log_warn() {
    if [ "2" -ge $LOG_LEVEL_INDEX ]; then
        log "${YELLOW}WARN${NC}" "$@"
    fi 
}

log_error() {
    if [ "3" -ge $LOG_LEVEL_INDEX ]; then
        log "${RED}ERROR${NC}" "$@"
    fi 
}