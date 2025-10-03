#!/usr/bin/env bash

# Build a Docker image
# Usage: build.sh <image-tag> <dockerfile>

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <image-tag> <dockerfile>" >&2
    exit 1
fi

IMAGE_TAG="$1"
DOCKERFILE="$2"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DOCKER_OPTIONS=""
DOCKER_OPTIONS+="-t $IMAGE_TAG:latest "
DOCKER_OPTIONS+="-f $SCRIPT_DIR/$DOCKERFILE "
DOCKER_OPTIONS+="--build-arg USER_ID=$(id -u) --build-arg USER_NAME=$(whoami) "

DOCKER_CMD="docker build $DOCKER_OPTIONS $SCRIPT_DIR"
echo $DOCKER_CMD
exec $DOCKER_CMD