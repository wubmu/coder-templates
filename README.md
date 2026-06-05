# Coder Templates

Coder 工作区模板仓库 — 为 homelab k3s 集群上的 Coder 提供开发环境定义。

## 目录结构

```
coder-templates/
├── docker/                  ← 自定义 workspace 镜像
│   └── base/               ←  基础镜像（公用工具链）
├── templates/               ← Coder 模板（Terraform）
│   └── k8s-basic/          ←  K8s Pod workspace 模板
├── scripts/                 ← 运维脚本
│   ├── build-images.sh     ←  构建 + 推送镜像
│   ├── push-templates.sh   ←  推送模板到 Coder
│   └── mirror-providers.sh ←  预下载 Terraform provider
├── config/
│   ├── providers.tf        ←  provider 声明（mirror 用）
│   └── terraformrc         ←  本地镜像配置
└── README.md
```

## 前置工具

```bash
# Terraform CLI（provider mirror 需要）
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

Coder CLI — 从 Coder 服务器下载（版本与服务器一致）：

```bash
# 替换为你的 Coder 地址
curl -fsSL https://coder.wyb.2wahaha.top/install.sh | sh
coder version
```

> 两个 CLI 都是一次性安装，日常推送模板和 mirror provider 需要用到。

## 快速开始

### 1. 构建 workspace 镜像

```bash
# 构建基础镜像
./scripts/build-images.sh base

# 或手动
docker build -t registry.example.com/coder/base:latest docker/base/
docker push registry.example.com/coder/base:latest
```

### 2. 预下载 Terraform provider（可选，离线/弱网环境）

```bash
# 一次性预下载 coder/coder + hashicorp/kubernetes 到 providers/
./scripts/mirror-providers.sh
```

然后在 **homelab** 侧将 `providers/` 目录挂载到 Coder server 容器，配合 `config/terraformrc` 或设置 `CODER_TERRAFORM_MIRROR_DIR` 环境变量即可离线创建 workspace。

### 3. 推送模板到 Coder

```bash
export CODER_URL=https://coder.wyb.2wahaha.top
export CODER_TOKEN=$(coder tokens create -n template-push)

./scripts/push-templates.sh k8s-basic
```

### 4. 在 Coder UI 使用模板

1. 打开 Coder → Templates
2. 找到推送的模板 → Create Workspace
3. 选择参数 → 等待创建完成

## 模板列表

| 模板 | 类型 | 说明 |
|------|------|------|
| k8s-basic | K8s Pod | 基础开发环境，通用工作区 |
| dev | K8s Pod (privileged) | 全栈开发 — GVM + NVM + dind |

## 与 homelab 的关系

- **homelab** ([../homelab](../homelab/)) — K8s 基础设施、Coder 服务部署
- **coder-templates**（本仓库）— Coder 上的工作区定义

homelab 负责把 Coder 服务跑起来，本仓库负责定义 Coder 能创建什么样的工作区。
两个仓库独立迭代，互不影响。

## 新增模板

```bash
mkdir -p templates/my-template
cp templates/k8s-basic/main.tf templates/my-template/main.tf
# 修改模板内容
./scripts/push-templates.sh my-template
```

## 环境变量参考

运行在本仓库依赖的 Coder 实例：

| 变量 | 说明 | 来源 |
|------|------|------|
| `CODER_URL` | Coder 服务地址 | homelab `coder.ingress.host` |
| `CODER_TOKEN` | Coder API token | `coder tokens create` |

## 许可

MIT
