# Coder 全栈开发 workspace 镜像
# 所有大文件通过 download.sh 预下载，docker build 无需下载 Go/Node/GVM/NVM
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
    locales xz-utils \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ============================================
#  创建 coder 用户
# ============================================
RUN groupadd -g ${GID} ${USER} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

# ============================================
#  GVM — 从本地 tarball 离线安装
# ============================================
COPY downloads/gvm/gvm-master.tar.gz /tmp/

RUN mkdir -p ${GVM_ROOT} \
    && tar -xzf /tmp/gvm-master.tar.gz -C ${GVM_ROOT} --strip-components=1 \
    && rm /tmp/gvm-master.tar.gz \
    && chown -R ${USER}:${USER} ${GVM_ROOT}

# 添加 shell 集成（GVM 本身 + Go 路径）
RUN echo '[ -s "$HOME/.gvm/scripts/gvm" ] && source "$HOME/.gvm/scripts/gvm"' >> /home/${USER}/.bashrc \
    && echo 'export GOPATH=$HOME/go' >> /home/${USER}/.bashrc \
    && echo 'export PATH=$GOROOT/bin:$GOPATH/bin:$PATH' >> /home/${USER}/.bashrc

# ============================================
#  NVM — 从本地 tarball 离线安装
# ============================================
COPY downloads/nvm/nvm-0.40.3.tar.gz /tmp/

RUN mkdir -p ${NVM_DIR} \
    && tar -xzf /tmp/nvm-0.40.3.tar.gz -C ${NVM_DIR} --strip-components=1 \
    && rm /tmp/nvm-0.40.3.tar.gz \
    && chown -R ${USER}:${USER} ${NVM_DIR}

RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /home/${USER}/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/${USER}/.bashrc

# ============================================
#  Go — 从本地 tarball 离线安装
# ============================================
COPY downloads/go/go${GO_VERSION}.linux-amd64.tar.gz /tmp/

RUN mkdir -p ${GVM_ROOT}/archive \
    && cp /tmp/go${GO_VERSION}.linux-amd64.tar.gz ${GVM_ROOT}/archive/ \
    # 先试着用 GVM binary install（命中本地缓存）
    && bash -c 'source "$HOME/.gvm/scripts/gvm" && gvm install go${GO_VERSION} -B' 2>/dev/null || true \
    # fallback: 手动解压到 GVM 管理的 gos 目录
    && if [ ! -d "${GVM_ROOT}/gos/go${GO_VERSION}" ]; then \
         mkdir -p ${GVM_ROOT}/gos/go${GO_VERSION} \
         && tar -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz -C ${GVM_ROOT}/gos/go${GO_VERSION} --strip-components=1 \
         && echo "  [fallback] Go installed via manual extract"; \
       fi \
    && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz \
    && chown -R ${USER}:${USER} ${GVM_ROOT}

ENV GOROOT=${GVM_ROOT}/gos/go${GO_VERSION}
ENV GOPATH=/home/${USER}/go
ENV PATH=${GVM_ROOT}/gos/go${GO_VERSION}/bin:${GOPATH}/bin:${PATH}

# ============================================
#  Node — 从本地 tarball 离线安装
# ============================================
COPY downloads/node/node-v${NODE_VERSION}-linux-x64.tar.xz /tmp/

RUN mkdir -p ${NVM_DIR}/.cache/bin \
    && cp /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz ${NVM_DIR}/.cache/bin/ \
    # 先试着用 NVM install（命中本地缓存）
    && bash -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
         && nvm install ${NODE_VERSION}' 2>/dev/null || true \
    # fallback: 手动解压到 NVM 管理的 versions 目录
    && if [ ! -d "${NVM_DIR}/versions/node/v${NODE_VERSION}" ]; then \
         mkdir -p ${NVM_DIR}/versions/node/v${NODE_VERSION} \
         && tar -xJf /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz -C ${NVM_DIR}/versions/node/v${NODE_VERSION} --strip-components=1 \
         && echo "  [fallback] Node installed via manual extract"; \
       fi \
    && rm /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz \
    && chown -R ${USER}:${USER} ${NVM_DIR}

ENV PATH=${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}

# ============================================
#  Docker CE（dind）— 保持在线安装
# ============================================
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
#  收尾
# ============================================
USER ${USER}
WORKDIR /home/${USER}
