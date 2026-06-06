# Wildcard Access URL 配置指南

## 有什么用

Template 里的 `coder_app` 配了 `subdomain = true` 后，workspace 应用（如 code-server）不再走 Coder 代理路径，而是通过独立子域名直接访问。

两种模式的对比：

```
# 默认代理模式（subdomain = false）
https://coder.wyb.2wahaha.top/@{user}/{workspace}/apps/code-server/

# subdomain 模式（启用 Wildcard Access URL 后）
https://code-server--{workspace}--{user}.coder.wyb.2wahaha.top
```

好处：
- 更短的 URL，用户体验更好
- 应用 OAuth 回调、WebSocket 等场景兼容性更好
- 浏览器安全策略（CORS/CSP）更易配置

## 怎么配

### 1. DNS 通配符解析

添加一条泛域名 DNS 记录，把 `*.coder.wyb.2wahaha.top` 指向 Coder server 所在 IP：

```dns
*.coder.wyb.2wahaha.top  →  <Coder Server 公网 IP>
```

### 2. Coder Server 环境变量

在 Coder deployment 上加两个环境变量：

```yaml
env:
  - name: CODER_ACCESS_URL
    value: "https://coder.wyb.2wahaha.top"
  - name: CODER_WILDCARD_ACCESS_URL
    value: "*.wyb.2wahaha.top"
```

- `CODER_ACCESS_URL` — Coder 对外访问地址（从集群内 DNS 改为公网地址）
- `CODER_WILDCARD_ACCESS_URL` — 通配符域名，Coder 用它拼接 workspace app 的子域名

### 3. 本项目配置位置

Homelab 仓库 `environments/dev/values.yaml`：

```yaml
coder:
  accessUrl: "https://coder.wyb.2wahaha.top"
  wildcardAccessUrl: "*.wyb.2wahaha.top"
```

通过 `releases/coder.yaml` 注入到 Coder deployment 的 extraEnv。

应用命令：

```bash
cd ~/homelab && HELMFILE_RENDER_YAML=true helmfile -e dev -l app=coder apply
```

### 4. Template 里的 subdomain 开关

Template 中 `coder_app` 的资源示例：

```hcl
resource "coder_app" "code-server" {
  agent_id  = coder_agent.main.id
  slug      = "code-server"
  url       = "http://localhost:8080"
  subdomain = true   # ← 开启子域名模式
  share     = "owner"
}
```

`subdomain = true` 告诉 Coder 为这个 app 生成独立子域名，格式为 `${slug}--${workspace}--${user}.${wildcard}`。

配置完成后重建 workspace 生效。
