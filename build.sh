#!/bin/bash

DOCKER_USER_NAME=${DOCKER_USER_NAME:-"rangareddy1988"}
IMAGE_NAME=${IMAGE_NAME:-"spark-python-compatibility-test"}
IMAGE_VERSION=${IMAGE_VERSION:-"1.0.0"}

if ! command -v docker &>/dev/null; then
  echo "Docker is not installed"
  exit 1
fi

# Check and Build the Docker image
if ! docker images "$IMAGE_NAME" | grep "$IMAGE_NAME" > /dev/null; then
    # Build the Docker image
    echo "Building the docker image $IMAGE_NAME"
    docker build \
        -t "${DOCKER_USER_NAME}/${IMAGE_NAME}:$IMAGE_VERSION" \
        -f Dockerfile . --progress=plain --no-cache
fi

# Check if the image build is successful
if ! docker images | grep "$IMAGE_NAME" > /dev/null; then
    echo "The build of Docker image $IMAGE_NAME failed."
    exit 1
else
    echo "The build of Docker image $IMAGE_NAME was successful."
fi

# Delete the dangling docker images
docker rmi $(docker images -f dangling=true) > /dev/null