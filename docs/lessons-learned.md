# 踩坑记录

Coder 离线/弱网环境下搭建 workspace 模板的经验总结。

## 1. Coder CLI 安装：install.sh 的 DNS 陷阱

**现象**：`curl -fsSL https://coder.wyb.2wahaha.top/install.sh | sh` 下载失败，报 `Could not resolve host: coder.coder.svc.cluster.local`

**原因**：Coder 的 install.sh 根据服务端的 `CODER_ACCESS_URL` 生成 binary 下载地址。如果 `accessUrl` 为空（dev 环境常见），install.sh fallback 到 K8s 内部 DNS `coder.coder.svc.cluster.local`，集群外无法解析。

**解决**：绕过 install.sh，直接从 ingress 拉 raw binary：

```bash
# 正确姿势（binary 在 /bin/coder-linux-amd64，是 raw ELF 不是 tar.gz）
curl -fsSL -o /tmp/coder https://coder.wyb.2wahaha.top/bin/coder-linux-amd64
sudo install /tmp/coder /usr/local/bin/coder

# 或者装个通用版 CLI（版本不必严格一致）
curl -fsSL https://cdr.co/install.sh | sh -s -- --version 2.18.5
```

**教训**：dev 环境的 `accessUrl` 留空方便集群内访问，但导致 install.sh 不可用。要么填上真实 URL，要么记住 binary 路径。

## 2. Terraform provider mirror：init + mirror 两步走

**现象**：直接创建目录结构、手动下载 zip 行不通。

**原因**：Terraform filesystem mirror 有严格的目录布局要求：
```
providers/registry.terraform.io/<namespace>/<name>/<name>_<version>_<os>_<arch>.zip
```
还必须有 `index.json` 和 `{version}.json` 元数据，手搓容易出错。

**正确姿势**：用 `terraform providers mirror` 自动生成：

```bash
# 1. 创建一个临时 tf 文件声明所有 provider
# 2. terraform init（下载到 .terraform/）
# 3. terraform providers mirror <output-dir>（复制到 mirror）
```

见 `config/providers.tf` + `scripts/mirror-providers.sh`。

**教训**：25MB 的 provider 走 terraform CLI 只需 30 秒，手动拼目录可能反复试错半天。

## 3. hostPath 的 UID 对齐

**现象**：container `runAsUser: 1000`，hostPath 文件 owner 是 root，Pod 启动后读不了 providers。

**原因**：hostPath 保留宿主机文件权限，不跟随 K8s fsGroup。PVC 的 fsGroup 只对 PVC 生效。

**解决**：
- 确保 host 上 providers 目录 owner = container UID（1000）
- 或者在 Pod spec 加 initContainer `chown 1000:1000 /home/coder/providers`
- k3s 单节点场景最简单：host 和 container 用同一个 UID（都是 1000）

本项目恰好 host 用户 `ubuntu` 的 UID 就是 1000，所以无需额外处理。

## 4. 双 PVC 在单节点 local-path 下没有意义

**现象**：最初 dev 模板用了两个 PVC（`/home` 和 `~/.docker`），自认为隔离更好。

**实际**：k3s local-path 不管创建几个 PVC，底层都在同一节点同一存储类上。`~/.docker` 本来就在 `/home/coder` 下，一个 volume 全包了。

**纠正**：merge 回单 PVC，`disk_size` 从 20Gi 调到 40Gi 覆盖 docker 镜像开销。

**原则**：local-path 场景下一个应用只建一个 PVC，除非真有跨节点需求。

## 5. GVM + NVM 离线安装的正确姿势

**前提交**：`~/.gvm/archive/` 和 `~/.nvm/.cache/bin/`

**GVM**：把 `go<ver>.linux-amd64.tar.gz` 放到 `~/.gvm/archive/` 后，
`gvm install go<ver> -B` 会优先从本地读取，不走网络。

**NVM**：把 `node-v<ver>-linux-x64.tar.xz` 放到 `~/.nvm/.cache/bin/` 后，
`nvm install <ver>` 命中缓存不下载。

**加 fallback**：`gvm install -B` 和 `nvm install` 不一定在 CI/离线环境正常工作（shell 环境变量问题），加手动解压的 fallback：
```dockerfile
RUN bash -c '...gvm install go1.23.4 -B || true' \
    && if [ ! -d "${GVM_ROOT}/gos/go1.23.4" ]; then \
         tar ... -xzf /tmp/go.tar.gz; \
       fi
```

## 6. `terraform providers mirror` vs Coder server 的 CODER_TERRAFORM_MIRROR_DIR

**关键发现**：Coder server (v2.33.2) 原生支持 `CODER_TERRAFORM_MIRROR_DIR` 环境变量，
直接指向 `terraform providers mirror` 生成的目录即可，
不需要手写 `.terraformrc`。

`config/terraformrc` 保留作为备选（旧版 Coder 或非标准路径场景），但日常用环境变量最简单。

## 总结：离线工作链路

```
[一次性准备]
  安装 terraform CLI  ─────────→  ./scripts/mirror-providers.sh
  安装 coder CLI     ─────────→  ./scripts/push-templates.sh

[镜像构建]           [Coder Server 挂载]
  docker build         hostPath: providers/
  (预置 Go/Node)       CODER_TERRAFORM_MIRROR_DIR

[推送模板]
  coder templates push dev --variable workspace_image=...
      ↓
  Coder server 内部 terraform init
      ↓
  命中本地 mirror — 不联网
```
