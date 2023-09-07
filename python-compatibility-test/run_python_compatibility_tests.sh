#!/bin/bash

### Description   : This script is used to run the Python compatibility tests
### Author        : Ranga Reddy <rangareddy.avula@gmail.com>
### Date          : 03-Sep-2023
### Version       : 1.0.0

# Include the log utility script
source /opt/log_util_file.sh

SCRIPT_NAME=`basename "$0"`

if [ $# -lt 1 ]; then
    printf "Usage: ${SCRIPT_NAME} <script_to_test_python_compatibility>\n"
    exit 1
fi

script_to_test_python_compatibility="$1"

# Check if the script to test Python compatibility exists.
if [ ! -f "$script_to_test_python_compatibility" ]; then
  log_error "The script $script_to_test_python_compatibility does not exist."
  exit 1
fi

# Log the start of the script.
log_debug "Starting Python Compatibility Tests using the $script_to_test_python_compatibility script"

# Define the Python versions that will be used for the compatibility tests.
export PYTHON_VERSIONS=("2.7" "3.4" "3.5" "3.6" "3.7" "3.8" "3.9" "3.10" "3.11" "3.12")

# Log the Python versions that will be used for the compatibility tests.
message="Running Python Compatibility tests using Python Versions: ${PYTHON_VERSIONS[@]}"
log_debug "$message"

# Creating the conda environment
# This function creates a conda environment with the specified Python version.
create_conda_env() {
    CONDA_ENV_NAME="$1"
    python_version="$2"

    # The function checks if the conda environment already exists.
    if ! conda env list | grep -q "$CONDA_ENV_NAME" ; then
        log_info "Creating the Python $CONDA_ENV_NAME environment..."
        retries=3
        # Retry the command 3 times
        for i in $(seq 1 $retries); do
            conda create -c conda-forge -y --name $CONDA_ENV_NAME python=$python_version > /dev/null
            if [ $? -eq 0 ]; then
                break
            fi
            sleep 2
        done
        if ! conda env list | grep -q "$CONDA_ENV_NAME" ; then
            log_info "Python environment $CONDA_ENV_NAME created successfully"
        else
            log_error "Python environment $CONDA_ENV_NAME creation failed"
        fi
    fi
}

# Run the Python Compatibility Tests
# This function loops through the list of Python versions and runs the compatibility tests for each version.
run_python_compatibility_tests() {
    counter=0
    #for python_version in "${PYTHON_VERSIONS[@]}"; do
    for ((i=${#PYTHON_VERSIONS[@]}-1; i>=0; i--)); do
        export python_version="${PYTHON_VERSIONS[$i]}"

        # Increment the counter variable
        ((counter++))
        export COUNTER="$counter"

        # Get the minimum Python version for the current Python version.
        local python_min_version=$(echo "$python_version" | tr -d .)

        # Create a conda environment with the current Python version.
        local CONDA_ENV_NAME="my_env_$(echo "$python_version" | sed 's/\./_/g')"
        create_conda_env "$CONDA_ENV_NAME" "$python_version"

        # If the conda environment exists, then run the compatibility tests.
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
            log_warn "Python environment $CONDA_ENV_NAME not created"
        fi
    done
}

# Run the Python compatibility tests.
run_python_compatibility_tests

# Log the completion of the script.
log_info "Completed Python Compatibility Tests using $script_to_test_python_compatibility script"