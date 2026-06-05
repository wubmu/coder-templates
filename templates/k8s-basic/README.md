# k8s-basic — K8s Pod Workspace 模板

每个工作区在 k3s 集群中创建一个独立 Pod，通过 Coder Agent 连接 IDE。

## 工作区结构

```
k3s node
  └── coder namespace
       ├── coder-{workspace-name} (Pod)
       │   ├── dev 容器 (workspace_image)
       │   │   ├── coder agent → 管理连接
       │   │   └── code-server → Web IDE
       │   └── /home/coder → PVC 持久化
       └── coder-{workspace-name}-home (PVC)
```

## 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `namespace` | `coder` | K8s 命名空间 |
| `workspace_image` | `ghcr.io/coder/coder:latest` | 工作区容器镜像 |
| `cpu` | `2` | CPU 核心数 |
| `memory` | `2Gi` | 内存 |
| `home_disk_size` | `10` | /home 持久化存储（Gi） |

## 推送模板

```bash
export CODER_URL=https://coder.wyb.2wahaha.top
export CODER_TOKEN=xxxxx

coder templates push k8s-basic \
  --directory templates/k8s-basic \
  --variable namespace=coder \
  --variable workspace_image=ghcr.io/coder/coder:latest
```

## 自定义 workspace 镜像

构建自己的镜像替代默认镜像：

```bash
# 构建
docker build -t registry.example.com/coder/dev:latest docker/base/

# 推送模板时指定
coder templates push k8s-basic \
  --directory templates/k8s-basic \
  --variable workspace_image=registry.example.com/coder/dev:latest
```
