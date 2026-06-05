# Coder 全栈开发 workspace 镜像
# 工具安装到 /opt/skel，首次启动时由 startup_script 复制到 $HOME（PVC）
# 镜像里的 /home/coder 仅作临时占位，真正内容由 PVC + skeleton 提供
FROM ubuntu:24.04

ARG USER=coder
ARG UID=1100
ARG GID=1100
ARG GO_VERSION=1.23.4
ARG NODE_VERSION=22.12.0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8

# ============================================
#  换阿里云 apt 源（国内加速）
# ============================================
RUN sed -i 's|//ports.ubuntu.com|//mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources \
    && sed -i 's|//archive.ubuntu.com|//mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources \
    && sed -i 's|//security.ubuntu.com|//mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources

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
ARG DOCKER_GID=988

RUN groupadd -g ${GID} ${USER} \
    && groupadd -g ${DOCKER_GID} docker-host 2>/dev/null || true \
    && useradd -m -u ${UID} -g ${GID} -G docker-host -s /bin/bash ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

# ============================================
#  骨架目录 /opt/skel — 所有持久化工具的模板
#  启动时 startup_script 一次性 cp -rn 到 $HOME（PVC）
# ============================================
ENV SKEL=/opt/skel
RUN mkdir -p ${SKEL}

# --------------------------------------------
#  GVM — 装到骨架
# --------------------------------------------
COPY downloads/gvm/gvm-master.tar.gz /tmp/

RUN mkdir -p ${SKEL}/.gvm \
    && tar -xzf /tmp/gvm-master.tar.gz -C ${SKEL}/.gvm --strip-components=1 \
    && rm /tmp/gvm-master.tar.gz

# --------------------------------------------
#  NVM — 装到骨架
# --------------------------------------------
COPY downloads/nvm/nvm-0.40.3.tar.gz /tmp/

RUN mkdir -p ${SKEL}/.nvm \
    && tar -xzf /tmp/nvm-0.40.3.tar.gz -C ${SKEL}/.nvm --strip-components=1 \
    && rm /tmp/nvm-0.40.3.tar.gz

# --------------------------------------------
#  Go — 装到骨架的 .gvm/gos/ 下
# --------------------------------------------
COPY downloads/go/go${GO_VERSION}.linux-amd64.tar.gz /tmp/

RUN mkdir -p ${SKEL}/.gvm/archive \
    && cp /tmp/go${GO_VERSION}.linux-amd64.tar.gz ${SKEL}/.gvm/archive/ \
    && mkdir -p ${SKEL}/.gvm/gos/go${GO_VERSION} \
    && tar -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz -C ${SKEL}/.gvm/gos/go${GO_VERSION} --strip-components=1 \
    && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz

# --------------------------------------------
#  Node — 装到骨架的 .nvm/versions/ 下
# --------------------------------------------
COPY downloads/node/node-v${NODE_VERSION}-linux-x64.tar.xz /tmp/

RUN mkdir -p ${SKEL}/.nvm/.cache/bin \
    && cp /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz ${SKEL}/.nvm/.cache/bin/ \
    && mkdir -p ${SKEL}/.nvm/versions/node/v${NODE_VERSION} \
    && tar -xJf /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz -C ${SKEL}/.nvm/versions/node/v${NODE_VERSION} --strip-components=1 \
    && rm /tmp/node-v${NODE_VERSION}-linux-x64.tar.xz

# --------------------------------------------
#  .bashrc — 骨架里的（复制到 PVC 后用户可改）
# --------------------------------------------
RUN echo '# ===== Coder workspace shell config =====' > ${SKEL}/.bashrc \
    && echo '' >> ${SKEL}/.bashrc \
    && echo 'export GVM_ROOT="$HOME/.gvm"' >> ${SKEL}/.bashrc \
    && echo 'export NVM_DIR="$HOME/.nvm"' >> ${SKEL}/.bashrc \
    && echo '' >> ${SKEL}/.bashrc \
    && echo '# GVM' >> ${SKEL}/.bashrc \
    && echo '[ -s "$GVM_ROOT/scripts/gvm" ] && source "$GVM_ROOT/scripts/gvm"' >> ${SKEL}/.bashrc \
    && echo '' >> ${SKEL}/.bashrc \
    && echo '# NVM' >> ${SKEL}/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ${SKEL}/.bashrc \
    && echo '' >> ${SKEL}/.bashrc \
    && echo '# Go (default '${GO_VERSION}')' >> ${SKEL}/.bashrc \
    && echo 'export GOROOT="$GVM_ROOT/gos/go'${GO_VERSION}'"' >> ${SKEL}/.bashrc \
    && echo 'export GOPATH="$HOME/go"' >> ${SKEL}/.bashrc \
    && echo 'export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"' >> ${SKEL}/.bashrc \
    && echo '' >> ${SKEL}/.bashrc \
    && echo '# Node (default v'${NODE_VERSION}')' >> ${SKEL}/.bashrc \
    && echo 'export PATH="$NVM_DIR/versions/node/v'${NODE_VERSION}'/bin:$PATH"' >> ${SKEL}/.bashrc \
    && echo '' >> ${SKEL}/.bashrc \
    && echo 'export PS1="\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "' >> ${SKEL}/.bashrc

# .profile — login shell 时 source .bashrc
RUN echo '[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"' > ${SKEL}/.profile \
    && chown ${USER}:${USER} ${SKEL}/.profile

# --------------------------------------------
#  统一 chown（所有骨架文件归 coder 用户）
# --------------------------------------------
RUN chown -R ${USER}:${USER} ${SKEL}

# ============================================
#  Docker CLI + Coder CLI（系统路径，不依赖 home）
# ============================================
COPY downloads/coder/coder /usr/local/bin/coder
COPY downloads/docker/docker /usr/local/bin/docker
RUN chmod +x /usr/local/bin/coder /usr/local/bin/docker

# ============================================
#  收尾
# ============================================
USER ${USER}
WORKDIR /home/${USER}
