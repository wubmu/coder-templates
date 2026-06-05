# dev — 全栈开发 Workspace 模板

每个 workspace 在 k3s 集群中创建一个 Pod，预装 GVM (Go 1.23) + NVM (Node 22) + Docker CLI（dood 模式）。

## 与 k8s-basic 的区别

| | k8s-basic | dev |
|---|---|---|
| securityContext | non-root | non-root（无需 privileged） |
| Docker | — | **dood**（挂宿主机 docker.sock） |
| 镜像 | coder 官方 | **coder-dev**（自建） |
| 工具 | — | Go 1.23 + Node 22 + Docker CLI |
| /home 存储 | 10Gi | **40Gi**（含源码） |

## dood 原理

```
workspace 容器内:
  docker build / docker run / docker ps
       ↓
  /var/run/docker.sock (hostPath 只读挂载)
       ↓
  宿主机 dockerd（执行实际操作）
```

比 dind 省 ~200MB 镜像体积，不用 privileged，构建的镜像直接存在宿主机上。

## 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `workspace_image` | `ghcr.io/coder/coder:latest` | 换成自己构建的 coder-dev 镜像 |
| `cpu` | `2` | CPU 核心数 |
| `memory` | `4Gi` | 内存 |
| `disk_size` | `40` | /home 持久化存储 (Gi) |

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
2. 宿主机 docker 组 GID = 988（镜像已硬编码），不一致时需重建
3. k3s 节点上有足够的磁盘空间（建议预留 40G+ 单个 workspace）
