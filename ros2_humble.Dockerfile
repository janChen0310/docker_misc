ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

ARG USER_NAME=default
ARG USER_ID=1000
ARG ROS_DISTRO=humble
ARG ROS2_BINARY_URL=https://github.com/ros2/ros2/releases/download/release-humble-20250721/ros2-humble-20250721-linux-jammy-amd64.tar.bz2

# Prevent anything requiring user input
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=linux

ENV TZ=America
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Base development tooling and desktop dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        clang \
        clang-format \
        cmake \
        curl \
        gdb \
        git \
        git-lfs \
        gnupg \
        graphviz \
        htop \
        iproute2 \
        iputils-ping \
        jq \
        less \
        lsb-release \
        mesa-utils \
        ninja-build \
        nano \
        net-tools \
        openssh-client \
        pkg-config \
        python3-pip \
        python3-venv \
        rsync \
        software-properties-common \
        sudo \
        tmux \
        tree \
        unzip \
        vim \
        wget \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Common robotics and perception build dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        can-utils \
        libassimp-dev \
        libbullet-dev \
        libeigen3-dev \
        libgazebo-dev \
        libgl1-mesa-dev \
        libglew-dev \
        libglu1-mesa-dev \
        libglfw3-dev \
        libopencv-dev \
        libomp-dev \
        libprotobuf-dev \
        libprotoc-dev \
        libsqlite3-dev \
        libusb-1.0-0-dev \
        libx11-dev \
        libxext-dev \
        libxi-dev \
        libxinerama-dev \
        libxrandr-dev \
        libxxf86vm-dev \
        libyaml-cpp-dev \
        protobuf-compiler \
        qtbase5-dev \
        usbutils \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    # find the username for TARGET_UID (empty if none)
    USERNAME="$(getent passwd "${USER_ID}" | cut -d: -f1)"; \
    if [ -n "$USERNAME" ]; then \
      # delete user and their home directory
      userdel -r "$USERNAME"; \
    fi

# Create a new user with the specified USER_ID and USER_NAME
RUN useradd -m -l -u ${USER_ID} -s /bin/bash ${USER_NAME} \
    && usermod -aG video ${USER_NAME} \
    && mkdir -p /home/${USER_NAME}/ros2_ws/src \
    && chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME} \
    && export PATH=$PATH:/home/${USER_NAME}/.local/bin

# Avoid shipping NVIDIA drivers in the container
RUN apt-get purge -y 'nvidia-*' 'libnvidia-*' || true

RUN echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Setup ROS 2 Humble from binary distribution
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    export LANG=en_US.UTF-8

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl \
                       dirmngr \
                       gpg-agent \
                       gnupg \
                       lsb-release \
                       software-properties-common; \
    apt-add-repository universe; \
    apt-get update; \
    ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}'); \
    curl -sSL -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"; \
    dpkg -i /tmp/ros2-apt-source.deb; \
    rm -f /tmp/ros2-apt-source.deb

RUN set -eux; \
    apt-get update; \
    apt-get install -y python3-rosdep python3-colcon-common-extensions python3-vcstool

RUN set -eux; \
    rosdep init || true; \
    rosdep update

RUN set -eux; \
    mkdir -p /opt/ros /opt/ros2_${ROS_DISTRO}; \
    curl -sSL --fail "${ROS2_BINARY_URL}" -o /tmp/ros2-${ROS_DISTRO}.tar.bz2; \
    tar -xjf /tmp/ros2-${ROS_DISTRO}.tar.bz2 -C /opt/ros2_${ROS_DISTRO}; \
    rm -f /tmp/ros2-${ROS_DISTRO}.tar.bz2; \
    ln -sfn /opt/ros2_${ROS_DISTRO}/ros2-linux /opt/ros/${ROS_DISTRO}; \
    rosdep install --from-paths /opt/ros/${ROS_DISTRO}/share --ignore-src -y --skip-keys "cyclonedds fastcdr fastrtps rti-connext-dds-6.0.1 urdfdom_headers"

# Additional ROS 2 packages from apt
RUN apt-get update && \
    apt-get install -y \
        ros-${ROS_DISTRO}-navigation2 \
        ros-${ROS_DISTRO}-nav2-bringup \
        ros-${ROS_DISTRO}-perception \
        ros-${ROS_DISTRO}-robot-state-publisher \
        ros-${ROS_DISTRO}-ros2-control \
        ros-${ROS_DISTRO}-ros2-controllers \
        ros-${ROS_DISTRO}-ros-gz-bridge \
        ros-${ROS_DISTRO}-slam-toolbox \
        ros-${ROS_DISTRO}-tf-transformations \
        ros-${ROS_DISTRO}-xacro \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup Gazebo
RUN apt-get update && \
    apt-get install -y ros-${ROS_DISTRO}-ros-gz ros-${ROS_DISTRO}-gz-ros2-control && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup Gazebo sensors
RUN apt-get update && \
    apt-get install -y lsb-release wget gnupg && \
    echo "deb [arch=$(dpkg --print-architecture)] \
      http://packages.osrfoundation.org/gazebo/ubuntu-stable \
      $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/gazebo-stable.list && \
    wget http://packages.osrfoundation.org/gazebo.key -O - | apt-key add - && \
    apt-get update

# Setup MoveIt2 
RUN apt-get update && \
    apt-get install -y ros-${ROS_DISTRO}-moveit ros-${ROS_DISTRO}-moveit-visual-tools ros-${ROS_DISTRO}-moveit-servo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Enter the workspace
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/ros2_ws

COPY ./entrypoint.sh /entrypoint.sh
RUN sudo chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]