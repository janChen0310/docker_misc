#!/usr/bin/env bash

# Run a Docker container
# Usage: run.sh <image-tag> <container-name> [restart]

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <image-tag> <container-name> [restart]" >&2
    exit 1
fi

IMAGE_TAG="$1"
CONTAINER_NAME="$2"
ACTION="${3:-}" 

USER_NAME=$(whoami)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
XRUN="/run/user/$(id -u)"

capabilities_str=\""capabilities=compute,utility,graphics,display\""

DOCKER_OPTIONS=""
DOCKER_OPTIONS+="-it "
DOCKER_OPTIONS+="-e DISPLAY=$DISPLAY "
DOCKER_OPTIONS+="-v /tmp/.X11-unix:/tmp/.X11-unix "
DOCKER_OPTIONS+="-v $(realpath $SCRIPT_DIR/../):/home/${USER_NAME}/$(basename $(realpath $SCRIPT_DIR/../)) "
DOCKER_OPTIONS+="-v /etc/group:/etc/group:ro "
DOCKER_OPTIONS+="-v /mnt/:/mnt/hostmnt "
DOCKER_OPTIONS+="-v $XRUN:$XRUN:rw "
DOCKER_OPTIONS+="-v /dev/input:/dev/input:ro "
DOCKER_OPTIONS+="-e XDG_RUNTIME_DIR=$XRUN "
DOCKER_OPTIONS+="--name $CONTAINER_NAME "
DOCKER_OPTIONS+="--privileged "
DOCKER_OPTIONS+="--net=host "
DOCKER_OPTIONS+="-e SDL_VIDEODRIVER=x11 "
DOCKER_OPTIONS+="-u $(id -u):$(id -g) "
DOCKER_OPTIONS+="--shm-size 32G "
DOCKER_OPTIONS+="-m 32g "
DOCKER_OPTIONS+="--cap-add SYS_MODULE "
DOCKER_OPTIONS+="--device /dev/dri:/dev/dri "
DOCKER_OPTIONS+="--group-add video "
DOCKER_OPTIONS+="--group-add render "

XAUTH=/tmp/.docker.xauth
if [ ! -f "$XAUTH" ]; then
    touch "$XAUTH"
    xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH" nmerge -
fi
chmod a+r "$XAUTH"
DOCKER_OPTIONS+="-e XAUTHORITY=$XAUTH "
DOCKER_OPTIONS+="-v $XAUTH:$XAUTH:ro "

for cam in /dev/video*; do
    DOCKER_OPTIONS+="--device=${cam} "
done

if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo "✔ NVIDIA GPU detected. Enabling GPU support."
    DOCKER_OPTIONS+="--gpus all "
    DOCKER_OPTIONS+="-e NVIDIA_VISIBLE_DEVICES=all "
    DOCKER_OPTIONS+="-e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,display "
    else
    echo "No NVIDIA GPU found. Running without GPU support."
fi

echo "$CONTAINER_NAME"

if [ "$ACTION" = "restart" ]; then 
    echo "Restarting Container"
    docker rm -f "$CONTAINER_NAME"
    docker run $DOCKER_OPTIONS "$IMAGE_TAG"
    # https://stackoverflow.com/questions/38576337/how-to-execute-a-bash-command-only-if-a-docker-container-with-a-given-name-does
elif [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then # If container isn't running
        
        # If it exists, but needs to be started
        if [  "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
            echo "Resuming Container"
            docker start "$CONTAINER_NAME"
            docker exec -it "$CONTAINER_NAME" /entrypoint.sh
        else
        echo "Running Container"
        docker run $DOCKER_OPTIONS "$IMAGE_TAG"
        fi
    else
    echo "Attaching to existing container"
    docker exec -it "$CONTAINER_NAME" /entrypoint.sh
fi
