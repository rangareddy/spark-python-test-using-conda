#!/bin/bash

export DATA_DIR=${DATA_DIR:-"/opt/data"}
export JUPYTER_PORT=${JUPYTER_PORT:-"8888"}
export JUPYTER_NOTEBOOK_DIR=${JUPYTER_NOTEBOOK_DIR:-"${DATA_DIR}/notebooks"}
mkdir -p $JUPYTER_NOTEBOOK_DIR

#export DATABASE_TYPE=${DATABASE_TYPE:-"sqllite3"}
#export DATABASE_NAME=${DATABASE_NAME:-"spark-python-test-db"}
#
#echo "Setup the $DATABASE_TYPE database"
#
#echo "Installing $DATABASE_TYPE client"
#if [ "$DATABASE_TYPE" == "mysql" ]; then
#    apt-get update && apt-get install -y default-mysql-client
#else
#    apt-get update && apt-get install -y sqlite3
#fi
#
#echo "Creating the database for type $DATABASE_TYPE"
#if [ "$DATABASE_TYPE" == "mysql" ]; then
#    export DATABASE_URL="mysql://root@localhost:3306/${DATABASE_NAME}"
#    export MYSQL_DATABASE=${DATABASE_NAME}
#    export MYSQL_USER=${MYSQL_USER:-"root"}
#    export MYSQL_PASSWORD=${MYSQL_PASSWORD:-"root"}
#else
#    echo "Setup the data directories for sqlite"
#    mkdir -p ${DATA_DIR}
#    touch ${DATA_DIR}/${DATABASE_NAME}.sqlite
#fi

echo "Running the jupyter notebook"

jupyter notebook \
    --notebook-dir=$JUPYTER_NOTEBOOK_DIR \
    --ip='*' --port=$JUPYTER_PORT \
    --NotebookApp.token='' --NotebookApp.password='' \
    --no-browser --allow-root