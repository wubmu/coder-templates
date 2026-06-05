# dev — 全栈开发 Workspace 模板

每个 workspace 在 k3s 集群中创建一个特权 Pod，预装 GVM (Go 1.23) + NVM (Node 22) + dind。

## 与 k8s-basic 的区别

| | k8s-basic | dev |
|---|---|---|
| securityContext | non-root | **privileged**（dind 需要） |
| 镜像 | coder 官方 | **coder-dev**（自建） |
| 工具 | 无 | Go 1.23 + Node 22 + Docker |
| /home 存储 | 10Gi | **40Gi**（含源码 + Docker 镜像） |

## 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `workspace_image` | `ghcr.io/coder/coder:latest` | 换成自己构建的 coder-dev 镜像 |
| `cpu` | `2` | CPU 核心数 |
| `memory` | `4Gi` | 内存 |
| `disk_size` | `40` | /home 持久化存储 (Gi)，含源码 + Docker 镜像/容器 |

## 推送模板

```bash
export CODER_URL=https://coder.wyb.2wahaha.top
export CODER_TOKEN=xxxxx

coder templates push dev \
  --directory templates/dev \
  --variable namespace=coder \
  --variable workspace_image=registry.example.com/coder/dev:latest
```

## 前置条件

1. 先构建并推送镜像：`docker/dev/` → `./download.sh && docker build -t ...`
2. 确保 Coder 的 ServiceAccount 有权限创建 privileged Pod
3. k3s 节点上有足够的磁盘空间（建议预留 40G+ 单个 workspace）
