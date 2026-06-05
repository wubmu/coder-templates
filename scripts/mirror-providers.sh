#!/usr/bin/env bash
set -euo pipefail

# 预下载所有 Terraform provider 到本地镜像目录
# 用法: ./mirror-providers.sh
#
# 输出: ../providers/（可挂载到 Coder server 容器）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
CONFIG_DIR="${ROOT_DIR}/config"
PROVIDERS_DIR="${ROOT_DIR}/providers"
TMPDIR="${TMPDIR:-/tmp}"

echo ">> 同步 Terraform providers 到本地镜像 ..."

# 在临时目录执行 terraform init + mirror，避免污染仓库
WORKDIR="${TMPDIR}/coder-tf-mirror-$$"
mkdir -p "${WORKDIR}"
trap "rm -rf ${WORKDIR}" EXIT

cp "${CONFIG_DIR}/providers.tf" "${WORKDIR}/main.tf"

cd "${WORKDIR}"

echo ">> terraform init ..."
terraform init

echo ">> terraform providers mirror ..."
mkdir -p "${PROVIDERS_DIR}"
terraform providers mirror "${PROVIDERS_DIR}"

echo ""
echo ">> 完成 — 镜像目录: ${PROVIDERS_DIR}"
find "${PROVIDERS_DIR}" -type f -name '*.zip' -exec du -h {} \; 2>/dev/null || find "${PROVIDERS_DIR}" -type f
echo ""
echo ">> 下一步: 将 ${PROVIDERS_DIR} 挂载到 Coder server，"
echo "   并设置 CODER_TERRAFORM_MIRROR_DIR=${PROVIDERS_DIR} 或使用 config/terraformrc"
