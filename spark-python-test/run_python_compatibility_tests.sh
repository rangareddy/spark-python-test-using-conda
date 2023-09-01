#!/bin/bash

if [ $? -eq 0 ]; then
  echo "Usage: $0 <script_to_test_python_compatibility>"
  exit 1
fi

script_to_test_python_compatibility="$1"

if [ ! -f "$script_to_test_python_compatibility" ]; then
  echo "The script $script_to_test_python_compatibility does not exist."
  exit 1
fi

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

log_info "Data Directory Path: $DATA_DIR"

export PYTHON_VERSIONS=("2.7" "3.4" "3.5" "3.6" "3.7" "3.8" "3.9" "3.10" "3.11")
log_info "Python Versions: ${PYTHON_VERSIONS[@]}"

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

# Run the Python Compatibility Tests
run_python_compatibility_tests() {
    for python_version in "${PYTHON_VERSIONS[@]}"; do
        local python_min_version=$(echo "$python_version" | tr -d .)
        local CONDA_ENV_NAME="my_env_$(echo "$python_version" | sed 's/\./_/g')"
        create_conda_env "$CONDA_ENV_NAME"

        # If conda environment exists then run the tests
        if conda env list | grep -q "$CONDA_ENV_NAME" ; then

            # Activate the created environment
            source /opt/conda/etc/profile.d/conda.sh
            conda activate "$CONDA_ENV_NAME"
            
            # Run the Python compatibility tests
            bash $script_to_test_python_compatibility

            # Deactivate and remove the conda environment
            conda deactivate 
            conda-env remove -n ${CONDA_ENV_NAME}
        else 
            log_warn "Environment ${CONDA_ENV_NAME} not created"
        fi
    done # python versions
}

log_info "Running the Python Compatibility Tests started"
run_python_compatibility_tests
log_info "The Python Compatibility Tests completed"