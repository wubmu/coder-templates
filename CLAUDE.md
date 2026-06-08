# CLAUDE.md

Coder workspace 模板仓库 — 为 homelab k3s 集群提供开发环境定义。两个模板：

| 模板 | 类型 | 镜像 | 说明 |
|------|------|------|------|
| `k8s-basic` | K8s Pod | `ghcr.io/coder/coder:latest` | 基础开发环境 |
| `dev` | K8s Pod (privileged) | `coder-dev:latest` | 全栈开发 — GVM + NVM + dind + code-server + VS Code |

## 环境变量

| 变量 | 用途 | 说明 |
|------|------|------|
| `CODER_URL` | push-templates | Coder 服务地址，如 `https://coder.wyb.2wahaha.top` |
| `CODER_TOKEN` | push-templates | `coder tokens create -n template-push` 生成 |
| `CODER_NAMESPACE` | push-templates | K8s 命名空间（默认 `coder`） |
| `REGISTRY` | build-images | 镜像仓库前缀，如 `registry.example.com/coder` |

## 构建镜像

```bash
# 1. 预下载离线依赖（只需一次，下载 GVM/NVM/Go/Node/Docker CLI/code-server/VS Code）
cd docker/dev && bash download.sh && bash download-vscode.sh && cd ../..

# 2. 构建 + 推送
REGISTRY=registry.example.com/coder bash scripts/build-images.sh dev
# 或只构建不推送: bash scripts/build-images.sh dev
```

## 推送模板

```bash
export CODER_URL=https://coder.wyb.2wahaha.top
export CODER_TOKEN=$(coder tokens create -n template-push)

# 方式一：wrapper 脚本（推荐）
bash scripts/push-templates.sh dev

# 方式二：裸命令
coder templates push dev --directory templates/dev --variable "namespace=coder" --yes
```

## 预下载 Terraform provider（离线用）

```bash
bash scripts/mirror-providers.sh
# 输出到 providers/，挂载到 Coder server 后设 CODER_TERRAFORM_MIRROR_DIR
```

## 踩坑

- **Shell 变量在 Terraform heredoc**：`startup_script` 里不要用 `${VAR}` — Terraform 会报 `Invalid reference`。用 `$VAR` 或 `$${VAR}` 转义
- **Coder install.sh DNS 陷阱**：install.sh 依赖 `CODER_ACCESS_URL` 生成 binary 下载地址，留空时 fallback 到集群内 DNS（`coder.coder.svc.cluster.local`），集群外无法解析。绕过：直接从 `/bin/coder-linux-amd64` 拉 raw binary
- **hostPath UID 对齐**：hostPath 保留宿主机文件权限，不跟随 K8s fsGroup。host 上 providers 目录 owner 必须与 container `runAsUser` 一致（本项目中 host 用户 ubuntu UID=1000）
- **k3s local-path 单 PVC 原则**：一个 workspace 只建一个 PVC，多 PVC 没有隔离意义（底层在同一节点同一存储类）
- **GVM/NVM 离线缓存**：Go tarball 放 `~/.gvm/archive/`、Node tarball 放 `~/.nvm/.cache/bin/` 可命中本地缓存，不走网络
- **Coder server provider mirror**：原生支持 `CODER_TERRAFORM_MIRROR_DIR` 环境变量，直接指向 `terraform providers mirror` 输出目录即可，不需要手写 `.terraformrc`
