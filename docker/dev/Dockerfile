# Coder 全栈开发 workspace 镜像
# 预置 GVM (Go 1.23) + NVM (Node 22) + dind
# Go/Node 二进制包离线预置在镜像内，workspace 启动后无需联网即可切换版本
FROM ubuntu:24.04

ARG USER=coder
ARG UID=1000
ARG GID=1000
ARG GO_VERSION=1.23.4
ARG NODE_VERSION=22.12.0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    GVM_ROOT=/home/${USER}/.gvm \
    NVM_DIR=/home/${USER}/.nvm

# ============================================
#  系统基础工具
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip \
    build-essential bison gcc make \
    vim htop jq tree silversearcher-ag \
    sudo openssh-client bash-completion \
    locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ============================================
#  创建 coder 用户
# ============================================
RUN groupadd -g ${GID} ${USER} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

# ============================================
#  安装 GVM（Go Version Manager）
# ============================================
USER ${USER}
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)" \
    && echo '[ -s "$HOME/.gvm/scripts/gvm" ] && source "$HOME/.gvm/scripts/gvm"' >> ~/.bashrc

# ============================================
#  安装 NVM（Node Version Manager）
# ============================================
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc

# ============================================
#  安装 Docker CE（dind）
# ============================================
USER root
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
             https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
       docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# dind 启动脚本
COPY dind-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/dind-entrypoint.sh

# ============================================
#  离线预置 Go — 从本地 tarball 安装
# ============================================
USER ${USER}
COPY downloads/go/go${GO_VERSION}.linux-amd64.tar.gz /tmp/

RUN mkdir -p ${GVM_ROOT}/archive \
    && cp /tmp/go${GO_VERSION}.linux-amd64.tar.gz ${GVM_ROOT}/archive/ \
    && bash -c 'source "$HOME/.gvm/scripts/gvm" && gvm install go${GO_VERSION} -B || true' \
    # 如果 GVM 没成功，手动解压
    && if [ ! -d "${GVM_ROOT}/gos/go${GO_VERSION}" ]; then \
         mkdir -p ${GVM_ROOT}/gos/go${GO_VERSION} \
         && tar -C ${GVM_ROOT}/gos/go${GO_VERSION} --strip-components=1 -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz; \
       fi \
    && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz

# 设置默认 Go
ENV GOROOT=${GVM_ROOT}/gos/go${GO_VERSION}
ENV GOPATH=/home/${USER}/go
ENV PATH=${GVM_ROOT}/gos/go${GO_VERSION}/bin:${GOPATH}/bin:${PATH}

# ============================================
#  离线预置 Node — 从本地 tarball 安装
# ============================================
COPY downloads/node/node-v${NODE_VERSION}-linux-x64.tar.xz /tmp/

RUN mkdir -p ${NVM_DIR}/.cache/bin \
    && cp /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz ${NVM_DIR}/.cache/bin/ \
    && bash -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
         && nvm install ${NODE_VERSION} || true' \
    # 如果 NVM 没成功，手动解压
    && if [ ! -d "${NVM_DIR}/versions/node/v${NODE_VERSION}" ]; then \
         mkdir -p ${NVM_DIR}/versions/node/v${NODE_VERSION} \
         && tar -C ${NVM_DIR}/versions/node/v${NODE_VERSION} --strip-components=1 -xJf /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz; \
       fi \
    && rm /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz

# 设置默认 Node
ENV PATH=${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}

# ============================================
#  收尾
# ============================================
USER ${USER}
WORKDIR /home/${USER}

# 写入 ~/.bashrc：自动加载 GVM + NVM，并设置默认 Go 路径
RUN printf '\n# --- Coder dev workspace ---\n' >> ~/.bashrc \
    && echo '[ -s "$HOME/.gvm/scripts/gvm" ] && source "$HOME/.gvm/scripts/gvm"' >> ~/.bashrc \
    && echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc \
    && echo 'export GOPATH=$HOME/go' >> ~/.bashrc \
    && echo 'export PATH=$GOROOT/bin:$GOPATH/bin:$PATH' >> ~/.bashrc
