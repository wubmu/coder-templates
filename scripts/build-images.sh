#!/usr/bin/env bash
set -euo pipefail

# 构建并推送 workspace 镜像
# 用法: ./build-images.sh <image-name> [tag]

IMAGE_NAME="${1:-base}"
IMAGE_TAG="${2:-latest}"
REGISTRY="${REGISTRY:-}"  # 如 registry.example.com/coder

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE_DIR="${SCRIPT_DIR}/../docker/${IMAGE_NAME}"

if [ ! -f "${DOCKERFILE_DIR}/Dockerfile" ]; then
  echo "错误: 找不到 docker/${IMAGE_NAME}/Dockerfile"
  echo "可用镜像:"
  ls "${SCRIPT_DIR}/../docker/" | grep -v README | sed 's/^/  - /'
  exit 1
fi

FULL_TAG="coder-${IMAGE_NAME}:${IMAGE_TAG}"
echo ">> 构建镜像: ${FULL_TAG}"
docker build -t "${FULL_TAG}" "${DOCKERFILE_DIR}"

if [ -n "${REGISTRY}" ]; then
  REMOTE_TAG="${REGISTRY}/coder-${IMAGE_NAME}:${IMAGE_TAG}"
  echo ">> 推送镜像: ${REMOTE_TAG}"
  docker tag "${FULL_TAG}" "${REMOTE_TAG}"
  docker push "${REMOTE_TAG}"
  echo ">> 完成: ${REMOTE_TAG}"
else
  echo ">> 完成: ${FULL_TAG}"
  echo ">> 提示: 设置 REGISTRY 环境变量以自动推送"
fi
