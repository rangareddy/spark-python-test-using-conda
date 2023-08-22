
#!/bin/bash
export CONDA_HOME="/opt/conda"

# Define Python versions to test
export PYTHON_VERSIONS=("2.7" "3.4" "3.5" "3.6" "3.7" "3.8" "3.9" "3.10" "3.11" "3.12")

# Creating the environments
create_conda_environment() {
    echo "Creating the Python environments Started"
    echo "======================================================="
    for PYTHON_VERSION in "${PYTHON_VERSIONS[@]}"; do
        CONDA_ENV_NAME="my_env_$(echo "$PYTHON_VERSION" | sed 's/\./_/g')"
        if [[ ! -d "$CONDA_HOME/envs/$CONDA_ENV_NAME" ]]; then
            echo "Creating the Python $CONDA_ENV_NAME environment..."
            conda create -y --name $CONDA_ENV_NAME python=$PYTHON_VERSION setuptools numpy pyarrow pandas scikit-learn matplotlib
            if [ $? -eq 0 ]; then
                echo "Python environment $CONDA_ENV_NAME created successfully"
            else
                echo "Python environment $CONDA_ENV_NAME creation failed"
            fi
        fi
    done
    echo "Creating Python environments Finished"
}

create_conda_environment