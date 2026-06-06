#!/usr/bin/env bash
set -euo pipefail

# 预下载 GVM + NVM + Go + Node（全部使用国内镜像）
# 用法: ./download.sh
#
# 下载完 docker build 无需联网

GO_VERSION="1.23.4"
NODE_VERSION="22.12.0"
NVM_VERSION="0.40.3"
GVM_BRANCH="master"

# 镜像源
MIRROR_GO="https://mirrors.aliyun.com/golang"
MIRROR_NODE="https://mirrors.aliyun.com/nodejs-release"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DL_DIR="${SCRIPT_DIR}/downloads"
mkdir -p "${DL_DIR}/go" "${DL_DIR}/node" "${DL_DIR}/gvm" "${DL_DIR}/nvm"

# ============================================
#  GVM — 预下载 GitHub repo
# ============================================
echo ">> 下载 GVM (moovweb/gvm) ..."
GVM_TGZ="${DL_DIR}/gvm/gvm-${GVM_BRANCH}.tar.gz"
GVM_URL="https://github.com/moovweb/gvm/archive/refs/heads/${GVM_BRANCH}.tar.gz"
if [ -f "${GVM_TGZ}" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${GVM_TGZ}" "${GVM_URL}"
  echo "  [完成] gvm-${GVM_BRANCH}.tar.gz ($(du -h "${GVM_TGZ}" | cut -f1))"
fi

# ============================================
#  NVM — 预下载 GitHub repo
# ============================================
echo ">> 下载 NVM (nvm-sh/nvm) v${NVM_VERSION} ..."
NVM_TGZ="${DL_DIR}/nvm/nvm-${NVM_VERSION}.tar.gz"
NVM_URL="https://github.com/nvm-sh/nvm/archive/refs/tags/v${NVM_VERSION}.tar.gz"
if [ -f "${NVM_TGZ}" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${NVM_TGZ}" "${NVM_URL}"
  echo "  [完成] nvm-${NVM_VERSION}.tar.gz ($(du -h "${NVM_TGZ}" | cut -f1))"
fi

# ============================================
#  Go — 阿里云镜像
# ============================================
echo ">> 下载 Go ${GO_VERSION} (阿里云镜像) ..."
GO_FILE="go${GO_VERSION}.linux-amd64.tar.gz"
if [ -f "${DL_DIR}/go/${GO_FILE}" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${DL_DIR}/go/${GO_FILE}" "${MIRROR_GO}/${GO_FILE}"
  echo "  [完成] ${GO_FILE} ($(du -h "${DL_DIR}/go/${GO_FILE}" | cut -f1))"
fi

# ============================================
#  Node — 阿里云镜像
# ============================================
echo ">> 下载 Node ${NODE_VERSION} (阿里云镜像) ..."
NODE_FILE="node-v${NODE_VERSION}-linux-x64.tar.xz"
if [ -f "${DL_DIR}/node/${NODE_FILE}" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${DL_DIR}/node/${NODE_FILE}" "${MIRROR_NODE}/v${NODE_VERSION}/${NODE_FILE}"
  echo "  [完成] ${NODE_FILE} ($(du -h "${DL_DIR}/node/${NODE_FILE}" | cut -f1))"
fi

# ============================================
#  Docker CLI — 阿里云静态二进制
# ============================================
echo ">> 下载 Coder Agent (从本地 Coder server) ..."
CODER_DIR="${DL_DIR}/coder"
mkdir -p "${CODER_DIR}"
if [ -f "${CODER_DIR}/coder" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${CODER_DIR}/coder" "https://coder.wyb.2wahaha.top/bin/coder-linux-amd64" || true
  if [ -s "${CODER_DIR}/coder" ]; then
    chmod +x "${CODER_DIR}/coder"
    echo "  [完成] coder ($(du -h "${CODER_DIR}/coder" | cut -f1))"
  else
    echo "  [失败] 无法下载，检查 Coder server 是否运行"
    exit 1
  fi
fi

DOCKER_VERSION="27.3.1"
echo ">> 下载 Docker CLI ${DOCKER_VERSION} (阿里云镜像) ..."
DOCKER_TGZ="docker-${DOCKER_VERSION}.tgz"
DOCKER_DIR="${DL_DIR}/docker"
mkdir -p "${DOCKER_DIR}"
if [ -f "${DOCKER_DIR}/docker" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${DOCKER_DIR}/${DOCKER_TGZ}" \
    "https://mirrors.aliyun.com/docker-ce/linux/static/stable/x86_64/${DOCKER_TGZ}"
  # 只解压 docker CLI，不要 dockerd/containerd
  tar -xzf "${DOCKER_DIR}/${DOCKER_TGZ}" -C /tmp docker/docker
  mv /tmp/docker/docker "${DOCKER_DIR}/docker"
  rm -rf /tmp/docker "${DOCKER_DIR}/${DOCKER_TGZ}"
  echo "  [完成] docker ($(du -h "${DOCKER_DIR}/docker" | cut -f1))"
fi

# ============================================
#  code-server — VS Code Web（预下载二进制）
# ============================================
CODE_SERVER_VERSION="4.123.0"
echo ">> 下载 code-server ${CODE_SERVER_VERSION} ..."
CODE_SERVER_DIR="${DL_DIR}/code-server"
mkdir -p "${CODE_SERVER_DIR}"
CODE_SERVER_URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz"
if [ -f "${CODE_SERVER_DIR}/code-server" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${CODE_SERVER_DIR}/code-server.tar.gz" "${CODE_SERVER_URL}" || true
  if [ -s "${CODE_SERVER_DIR}/code-server.tar.gz" ] && [ "$(stat -c%s "${CODE_SERVER_DIR}/code-server.tar.gz")" -gt 1000 ]; then
    tar -xzf "${CODE_SERVER_DIR}/code-server.tar.gz" -C "${CODE_SERVER_DIR}" --strip-components=1
    rm "${CODE_SERVER_DIR}/code-server.tar.gz"
    chmod +x "${CODE_SERVER_DIR}/code-server"
    echo "  [完成] code-server ($(du -h "${CODE_SERVER_DIR}/code-server" | cut -f1))"
  else
    rm -f "${CODE_SERVER_DIR}/code-server.tar.gz"
    echo "  [失败] 下载失败，检查网络或手动下载 code-server 放到 ${CODE_SERVER_DIR}/code-server"
  fi
fi

echo ""
echo "========================================"
echo ">> 预下载完成"
du -sh "${DL_DIR}/gvm/"* "${DL_DIR}/nvm/"* "${DL_DIR}/go/"* "${DL_DIR}/node/"* "${DL_DIR}/code-server/"* 2>/dev/null
echo "========================================"
echo ">> 现在可以离线构建："
echo "   docker build -t coder-dev:latest ."
