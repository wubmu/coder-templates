#!/bin/bash
set -euo pipefail

VERSION="${1:-1.123.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${SCRIPT_DIR}/downloads/vscode"

# ---- 加载镜像源配置 ----
if [ -f "${SCRIPT_DIR}/mirrors.env" ]; then
  source "${SCRIPT_DIR}/mirrors.env"
fi

VSCODE_VERSION_API="${VSCODE_VERSION_API:-https://update.code.visualstudio.com/api/versions}"
VSCODE_DOWNLOAD_BASE="${VSCODE_DOWNLOAD_BASE:-https://vscode.download.prss.microsoft.com/dbazure/download}"

mkdir -p "$DEST"

# ---- 查询 VS Code 版本对应的 commit ID ----
echo ">>> Resolving commit for VS Code ${VERSION}..."
COMMIT=$(curl -sS "${VSCODE_VERSION_API}/${VERSION}/linux-x64/stable" | jq -r .version)

if [ -z "$COMMIT" ] || [ "$COMMIT" = "null" ]; then
  echo "ERROR: Failed to resolve commit for version ${VERSION}"
  exit 1
fi
echo ">>> Commit: ${COMMIT}"

# ---- 写入 commit.txt 供 Dockerfile 使用 ----
echo "$COMMIT" > "$DEST/commit.txt"

# ---- 下载 CLI (x64) ----
echo ">>> Downloading vscode_cli_alpine_x64_cli.tar.gz..."
curl -#L -o "$DEST/vscode_cli_alpine_x64_cli.tar.gz" \
  "${VSCODE_DOWNLOAD_BASE}/stable/${COMMIT}/vscode_cli_alpine_x64_cli.tar.gz"

# ---- 下载 Server (x64) ----
echo ">>> Downloading vscode-server-linux-x64.tar.gz..."
curl -#L -o "$DEST/vscode-server-linux-x64.tar.gz" \
  "${VSCODE_DOWNLOAD_BASE}/stable/${COMMIT}/vscode-server-linux-x64.tar.gz"

echo ">>> Done. VS Code ${VERSION} (${COMMIT}) → ${DEST}"
ls -lh "$DEST/"
