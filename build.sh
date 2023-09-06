#!/bin/bash

DOCKER_USER_NAME=${DOCKER_USER_NAME:-"rangareddy1988"}
IMAGE_NAME=${IMAGE_NAME:-"python-compatibility-test"}
MINICONDA_VERSION=${MINICONDA_VERSION:-"23.5.2-0"}
TAG_VERSION=$(echo "$MINICONDA_VERSION" | sed 's/\./_/g' | sed 's/-/_/g')
TAG_NAME="${DOCKER_USER_NAME}/${IMAGE_NAME}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
DONE="[${GREEN}DONE${NC}]"
PROGRESS="[${YELLOW}....${NC}]"

if ! command -v docker &>/dev/null; then
  echo -ne "${RED} Docker is not installed\r"
  exit 1
fi

# Build the Docker image
echo -ne "${PROGRESS} Building the Docker image $IMAGE_NAME\r"
if [[ $(uname -m) == 'arm64' ]]; then
    export DOCKER_DEFAULT_PLATFORM="linux/amd64"
fi
docker build \
    --build-arg MINICONDA_VERSION=$MINICONDA_VERSION \
    --build-arg IMAGE_VERSION=$TAG_VERSION \
    -t "${TAG_NAME}:${TAG_VERSION}" \
    -t "${TAG_NAME}:latest" \
    -f python-compatibility-test/Dockerfile . \
    --progress=plain --no-cache

# Check if the image build is successful
if ! docker images | grep "$TAG_NAME" > /dev/null; then
    echo -ne "${RED} Docker image $IMAGE_NAME build was failed\r"
    exit 1
else
    echo -ne "${DONE} Docker image $IMAGE_NAME build was successful\r"
fi

# Remove the old containers
echo -ne "${PROGRESS} Remove old containers\r"
docker rm -v $(docker ps -q -f status=exited 2>/dev/null) 2>/dev/null
echo -ne "${DONE} Remove old containers\r"

# Delete the dangling docker images
echo -ne "${PROGRESS} Remove dangling images\r"
docker rmi $(docker images -q -f dangling=true) 2>/dev/null
echo -ne "${DONE} Remove dangling images\r"