# Coder 基础 workspace 镜像
# 在此镜像基础上可以派生语言专用镜像（go-dev、python-dev 等）
FROM ubuntu:24.04

ARG USER=coder
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# 系统基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    locales \
    sudo \
    openssh-client \
    bash-completion \
    vim \
    htop \
    jq \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户（Coder 要求）
RUN groupadd -g ${GID} ${USER} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# 语言版本管理器（可选，按需取消注释）
# RUN curl -fsSL https://github.com/nvm-sh/nvm/raw/master/install.sh | bash
# RUN curl -fsSL https://go.dev/dl/go1.23.linux-amd64.tar.gz | tar -C /usr/local -xz
