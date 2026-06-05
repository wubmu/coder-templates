# Dev Workspace Image

基于 Ubuntu 24.04 的全栈开发环境，预装 GVM + NVM + Docker-in-Docker。
Go 1.23 和 Node 22 二进制包离线预置在镜像内。

## 包含工具

| 工具 | 预置版本 |
|------|---------|
| GVM | Go 1.23.4（离线可用） |
| NVM | Node 22.12.0（离线可用） |
| dind | Docker-in-Docker（dockerd 自动启动） |
| 其他 | git, curl, vim, htop, jq, build-essential |

## 离线构建

```bash
# 1. 预下载（只需执行一次）
./download.sh

# 2. 构建镜像（无需联网）
docker build -t coder-dev:latest .

# 3. 推送
docker tag coder-dev:latest registry.example.com/coder/dev:latest
docker push registry.example.com/coder/dev:latest
```
