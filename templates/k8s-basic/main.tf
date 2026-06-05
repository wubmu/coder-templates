terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

variable "namespace" {
  type    = string
  default = "coder"
}

variable "workspace_image" {
  type    = string
  default = "ghcr.io/coder/coder:latest"
}

variable "cpu" {
  type    = number
  default = 2
}

variable "memory" {
  type    = string
  default = "2Gi"
}

variable "disk_size" {
  type    = number
  default = 10
}

variable "home_disk_size" {
  type    = number
  default = 10
}

provider "kubernetes" {
  # 集群内运行时无需额外配置（Coder server 已部署在 k3s）
}

provider "coder" {}

# 每个 workspace 生成唯一名称
data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {
  username = data.coder_workspace.me.owner
}

# ---- PVC（持久化 /home） ----
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = lower(data.coder_workspace.me.name)
      "app.kubernetes.io/part-of"  = "coder"
      "coder/workspace"            = lower(data.coder_workspace.me.name)
      "coder/owner"                = lower(data.coder_workspace_owner.me.name)
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.home_disk_size}Gi"
      }
    }
  }
}

# ---- Workspace Pod ----
resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = lower(data.coder_workspace.me.name)
      "app.kubernetes.io/part-of"  = "coder"
      "coder/workspace"            = lower(data.coder_workspace.me.name)
      "coder/owner"                = lower(data.coder_workspace_owner.me.name)
    }
    annotations = {
      "coder/workspace-url" = data.coder_workspace.me.access_url
    }
  }
  spec {
    service_account_name = "coder"
    restart_policy       = "Never"
    # 安全上下文
    security_context {
      run_as_user  = 1000
      run_as_group = 1000
      fs_group     = 1000
    }
    container {
      name              = "dev"
      image             = var.workspace_image
      image_pull_policy = "IfNotPresent"
      # Coder agent（管理连接 + IDE）
      command = ["sh", "-c", <<-EOS
        curl -fsSL https://coder.com/install.sh | sh -s -- --version ${data.coder_workspace.me.transition == "delete" ? "0.0.0" : coder_agent.main.version} &&
        exec coder agent
      EOS
      ]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      resources {
        requests = {
          cpu    = "${var.cpu}"
          memory = var.memory
        }
        limits = {
          cpu    = "${var.cpu * 2}"
          memory = var.memory
        }
      }
      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
        read_only  = false
      }
    }
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata[0].name
        read_only  = false
      }
    }
  }
}

# ---- Coder Agent（IDE 连接 + 生命周期管理） ----
resource "coder_agent" "main" {
  arch                   = "amd64"
  os                     = "linux"
  dir                    = "/home/coder"
  connection_timeout     = 300
  startup_script_timeout = 300
  login_before_ready     = false

  metadata {
    display_name = "CPU"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 5
    timeout      = 2
  }
  metadata {
    display_name = "Memory"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 5
    timeout      = 2
  }
  metadata {
    display_name = "Disk"
    key          = "disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 10
    timeout      = 2
  }

  startup_script = <<-EOS
    set -e
    # 安装常用 CLI 工具（按需修改）
    if command -v apt-get > /dev/null 2>&1; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq tree silversearcher-ag 2>/dev/null || true
    fi
    # 设置 Coder 友好的提示符
    echo 'export PS1="\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "' >> ~/.bashrc
  EOS

  shutdown_script = <<-EOS
    echo "Shutting down workspace..."
  EOS
}

# ---- 应用（IDE agent + 可选 Web 应用） ----
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Server"
  url          = "http://localhost:8080"
  icon         = "/icon/code.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080/healthz"
    interval  = 10
    threshold = 15
  }
}
