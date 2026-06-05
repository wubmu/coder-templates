# Docker CE 安装（阿里云镜像）

适用 Ubuntu 24.04，国内网络环境。

## 安装

```bash
# 1. 信任 Docker GPG 密钥（阿里云镜像）
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 2. 添加 apt 源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list

# 3. 安装
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 4. 免 sudo
sudo usermod -aG docker $USER
# 重新登录生效，或 newgrp docker

# 5. 验证
docker version
```

## 镜像加速（可选）

```bash
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": ["https://docker.1ms.run"]
}
EOF
sudo systemctl restart docker
```

## 与 k3s containerd 的关系

Docker 自带一个 containerd 实例，与 k3s 的 containerd 独立运行：

| | Docker containerd | k3s containerd |
|---|---|---|
| 用途 | `docker build` / `docker run` | K8s Pod 运行时 |
| Socket | `/var/run/docker.sock` | `/run/k3s/containerd/containerd.sock` |
| 数据目录 | `/var/lib/docker/` | `/var/lib/rancher/k3s/agent/containerd/` |
| 管理 | `systemctl` | k3s 自带 |

两者不会冲突，镜像存储和进程完全隔离。

## 卸载

```bash
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm -rf /var/lib/docker /var/lib/containerd
```
