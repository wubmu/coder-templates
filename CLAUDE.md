# CLAUDE.md

Coder workspace 模板仓库 — 定义 homelab k3s 集群上的开发环境。**本仓库不运行任何服务**，只生产两类产物：

1. **Docker 镜像**（`docker/`）— workspace 里跑什么工具
2. **Terraform 模板**（`templates/`）— workspace 怎么在 K8s 上创建

两者通过模板里的 `var.workspace_image` 关联：模板引用镜像，Coder Server 执行模板时拉镜像起 Pod。
Coder Server 本身部署在 homelab 仓库，本仓库只定义 workspace 模板。

## 核心架构：Skeleton 模式

dev 模板最关键的設計是 **Skeleton（骨架）模式**，解决了一个矛盾：

- 用户数据要持久化 → 必须走 PVC（`/home/coder` 是 PVC 挂载）
- 开发工具要预装到镜像 → 但镜像里的 `/home/coder` 会被 PVC 覆盖

所以分两步：

```
构建时（Dockerfile）                    启动时（startup_script）
─────────────────────                   ────────────────────────
COPY 所有工具 → /opt/skel/    ──→    cp -rn /opt/skel/. → $HOME/
  .gvm/                                   .gvm/
  .nvm/                                   .nvm/
  .bashrc                                 .bashrc
  .vscode-server/                         .vscode-server/
```

- 镜像提供"骨架"（`/opt/skel`），首次启动复制到 PVC
- `SKEL_VERSION` 控制更新：bump 版本号 → 下次启动重新复制骨架（不覆盖用户已修改的文件，`cp -rn`）
- 系统级工具（`coder`、`docker` CLI、`code-server`）直接装 `/usr/local/bin`，不走骨架

## 完整链路

```
docker/dev/download.sh        docker/dev/Dockerfile       scripts/build-images.sh
  预下载 Go/Node/GVM/NVM          COPY → /opt/skel           docker build + push
  Docker CLI/code-server          COPY → /usr/local/bin           │
  VS Code server                                               registry
                                                                  │
templates/dev/main.tf  ──terraform apply──→  K8s Pod  ──拉镜像──→┘
  coder_agent (startup_script)
  coder_app  (code-server :8080)
  PVC (/home/coder)
  hostPath docker.sock

scripts/push-templates.sh dev  ──→  Coder Server  ──→ 用户在 UI 创建 workspace
```

Coder 模板的两个核心 resource：
- `coder_agent` — Pod 内的 agent 进程，执行 startup_script、上报 metadata、维持与 Coder Server 的连接
- `coder_app` — 把 agent 内部端口暴露为 Coder UI 上的可点击应用（如 code-server），`subdomain = true` 生成独立子域名，格式 `${slug}--${workspace}--${user}.${wildcard}`

关键点：
- **离线优先**：整个链路设计目标是不依赖公网 — Go/Node/GVM/NVM/Docker CLI/code-server/VS Code Server 全部 `download.sh` 预下载，Terraform provider 走本地 mirror，workspace 启动后工具立即可用，零网络等待
- **镜像源**：apt/Go/Node/Docker CLI/npm 镜像源统一配置在 `docker/dev/mirrors.env`，`download.sh` 和 `Dockerfile` 都从它读取，换源只改一个文件
- **Docker-in-Docker**：不走真正的 dind，而是挂载宿主 `/var/run/docker.sock`（dood 模式），容器里只有 Docker CLI

## 两个模板

| | k8s-basic | dev |
|------|-----------|-----|
| 镜像 | `ghcr.io/coder/coder:latest`（官方） | `coder-dev:latest`（自建） |
| 工具 | 最小化（curl/git 后现场装） | GVM + Go 1.23 + NVM + Node 22 + Docker CLI + code-server + VS Code |
| Docker | ❌ | ✅ hostPath docker.sock |
| 骨架 | ❌ | ✅ `/opt/skel` → PVC |
| PVC | `/home/coder`（10Gi） | `/home/coder`（40Gi，含 Docker 镜像开销） |
| securityContext | `runAsUser: 1000` | `runAsUser: 1100` |

k8s-basic 是通用最小模板，dev 是全栈开发模板。新增模板建议从 k8s-basic 复制起手。

## 日常操作

```bash
# === 构建 dev 镜像 ===
cd docker/dev
bash download.sh            # 预下载 Go/Node/GVM/NVM/Docker CLI/code-server（只需一次）
bash download-vscode.sh     # 预下载 VS Code CLI + Server（只需一次）
cd ../..
REGISTRY=registry.example.com/coder bash scripts/build-images.sh dev

# === 推送模板 ===
export CODER_URL=https://coder.wyb.2wahaha.top
export CODER_TOKEN=$(coder tokens create -n template-push)
bash scripts/push-templates.sh dev

# === Provider mirror（离线环境用） ===
bash scripts/mirror-providers.sh
# 输出 providers/ → 挂载到 Coder Server + 设 CODER_TERRAFORM_MIRROR_DIR
```

## 环境变量

| 变量 | 脚本 | 说明 |
|------|------|------|
| `CODER_URL` | push-templates | Coder 服务地址 |
| `CODER_TOKEN` | push-templates | `coder tokens create` 生成 |
| `CODER_NAMESPACE` | push-templates | K8s 命名空间（默认 `coder`） |
| `REGISTRY` | build-images | 镜像仓库前缀 |

## 踩坑

- **Terraform heredoc 里的 `${VAR}`**：会被 Terraform 当成自己的变量引用报 `Invalid reference`。用 `$VAR` 或 `$${VAR}`
- **Coder install.sh DNS 陷阱**：`CODER_ACCESS_URL` 为空时 install.sh fallback 到集群内 DNS，集群外无法解析。绕过：直接拉 `/bin/coder-linux-amd64` raw binary
- **hostPath UID 对齐**：hostPath 不跟随 fsGroup，host 上文件 owner 必须与 container `runAsUser` 一致
- **k3s local-path 单 PVC**：多 PVC 在单节点无隔离意义，一个 workspace 只建一个 PVC
- **GVM/NVM 离线缓存路径**：Go tarball → `~/.gvm/archive/`，Node tarball → `~/.nvm/.cache/bin/`
- **Provider mirror 用环境变量**：Coder Server 原生支持 `CODER_TERRAFORM_MIRROR_DIR`，不需要手写 `.terraformrc`
