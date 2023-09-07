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
    local level_index="$1"
    local message="$2"

    if [ "$level_index" -ge $LOG_LEVEL_INDEX ]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        level_msg=${LOG_LEVELS[$level_index]}
        if [ "3" == $level_index ]; then
            level="${RED}${level_msg}${NC}"
        elif [ "2" -eq $level_index ]; then
            level="${YELLOW}${level_msg}${NC}"
        elif [ "1" -eq $level_index ]; then
            level="${GREEN}${level_msg}${NC}"
        else 
            level="${level_msg}"
        fi 
        echo -e "[$timestamp][$level] $message"
        echo -e "[$timestamp][$level_msg] $message" >> "$OUTPUT_LOG_FILE"
    fi
}

log_debug() {
    log "0" "$@" 
}

log_info() {
    log "1" "$@"
}

log_warn() {
    log "2" "$@"
}

log_error() {
    log "3" "$@"
}