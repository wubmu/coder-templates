# Base Workspace Image

Coder 工作区基础镜像。包含常用开发工具，指定语言/框架的专用镜像从此派生。

## 构建

```bash
docker build -t coder-base:latest .
# 或通过脚本
../../scripts/build-images.sh base
```

## 自定义

按项目需要修改 Dockerfile，添加/删除工具。常见扩展：

```dockerfile
# 继承基础镜像
FROM coder-base:latest

# Go 开发工具
RUN curl -fsSL https://go.dev/dl/go1.23.linux-amd64.tar.gz | sudo tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:$PATH"

# Python 开发工具
# RUN sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv
```

## 推送

```bash
docker tag coder-base:latest registry.your-domain.com/coder/base:latest
docker push registry.your-domain.com/coder/base:latest
```
