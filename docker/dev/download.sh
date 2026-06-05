#!/usr/bin/env bash
set -euo pipefail

# 预下载 Go 1.23 + Node 22 二进制包（离线构建用）
# 用法: ./download.sh

GO_VERSION="1.23.4"
NODE_VERSION="22.12.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GO_DIR="${SCRIPT_DIR}/downloads/go"
NODE_DIR="${SCRIPT_DIR}/downloads/node"
mkdir -p "${GO_DIR}" "${NODE_DIR}"

echo ">> 下载 Go ${GO_VERSION} ..."
GO_FILE="go${GO_VERSION}.linux-amd64.tar.gz"
if [ -f "${GO_DIR}/${GO_FILE}" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${GO_DIR}/${GO_FILE}" "https://go.dev/dl/${GO_FILE}"
  echo "  [完成] ${GO_FILE} ($(du -h "${GO_DIR}/${GO_FILE}" | cut -f1))"
fi

echo ">> 下载 Node ${NODE_VERSION} ..."
NODE_FILE="node-v${NODE_VERSION}-linux-x64.tar.xz"
if [ -f "${NODE_DIR}/${NODE_FILE}" ]; then
  echo "  [跳过] 已存在"
else
  curl -fsSL -o "${NODE_DIR}/${NODE_FILE}" "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_FILE}"
  echo "  [完成] ${NODE_FILE} ($(du -h "${NODE_DIR}/${NODE_FILE}" | cut -f1))"
fi

echo ">> 下载完成"
