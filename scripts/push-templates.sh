#!/usr/bin/env bash
set -euo pipefail

# 推送模板到 Coder 服务器
# 用法: ./push-templates.sh <template-name>
#
# 环境变量:
#   CODER_URL    — Coder 服务地址 (必填)
#   CODER_TOKEN  — Coder API token (必填，可通过 coder tokens create 生成)
#   CODER_NAMESPACE — K8s 命名空间（默认 coder）

TEMPLATE_NAME="${1:-}"
CODER_NAMESPACE="${CODER_NAMESPACE:-coder}"

if [ -z "${TEMPLATE_NAME}" ]; then
  echo "用法: $0 <template-name>"
  echo ""
  echo "可用模板:"
  ls "$(dirname "$0")/../templates/" | sed 's/^/  - /'
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates/${TEMPLATE_NAME}"

if [ ! -f "${TEMPLATE_DIR}/main.tf" ]; then
  echo "错误: 找不到 templates/${TEMPLATE_NAME}/main.tf"
  exit 1
fi

# 检查环境变量
: "${CODER_URL:?请设置 CODER_URL}"
: "${CODER_TOKEN:?请设置 CODER_TOKEN，可通过 coder tokens create 生成}"

echo ">> 推送模板: ${TEMPLATE_NAME}"
echo "   Coder URL: ${CODER_URL}"
echo "   Namespace: ${CODER_NAMESPACE}"
echo "   目录:      ${TEMPLATE_DIR}"

coder templates push "${TEMPLATE_NAME}" \
  --directory "${TEMPLATE_DIR}" \
  --variable "namespace=${CODER_NAMESPACE}" \
  --yes

echo ">> 完成: ${TEMPLATE_NAME} 模板已推送"
