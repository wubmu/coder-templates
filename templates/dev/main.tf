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
  default = "1Gi"
}

variable "disk_size" {
  type    = number
  default = 40
  description = "/home 持久化存储（含源码 + Docker 镜像/容器）"
}

provider "kubernetes" {}

provider "coder" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# ---- PVC: /home 持久化（含源码 + Docker 数据） ----
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = lower(data.coder_workspace.me.name)
      "coder/workspace"            = lower(data.coder_workspace.me.name)
      "coder/owner"                = lower(data.coder_workspace_owner.me.name)
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.disk_size}Gi"
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
    container {
      name              = "dev"
      image             = var.workspace_image
      image_pull_policy = "IfNotPresent"
      command           = ["sh", "-c"]
      args = ["sh", "-c", "curl -fsSL https://coder.com/install.sh | sh && exec coder agent"]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      # dood 模式：宿主机 docker，无需 privileged
      security_context {
        run_as_user  = 1100
        run_as_group = 1100
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
      volume_mount {
        name       = "docker-sock"
        mount_path = "/var/run/docker.sock"
        read_only  = true
      }
    }
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata[0].name
        read_only  = false
      }
    }
    volume {
      name = "docker-sock"
      host_path {
        path = "/var/run/docker.sock"
        type = "Socket"
      }
    }
  }
}

# ---- Coder Agent ----
resource "coder_agent" "main" {
  arch               = "amd64"
  os                 = "linux"
  connection_timeout = 300

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
    display_name = "Disk (/home)"
    key          = "disk_home"
    script       = "coder stat disk --path /home/coder"
    interval     = 10
    timeout      = 2
  }
  metadata {
    display_name = "Go"
    key          = "go"
    script       = "go version 2>/dev/null || echo 'N/A'"
    interval     = 30
    timeout      = 2
  }
  metadata {
    display_name = "Node"
    key          = "node"
    script       = "node --version 2>/dev/null || echo 'N/A'"
    interval     = 30
    timeout      = 2
  }

  startup_script = <<-EOS
    set -e
    # 常用工具（镜像已有，确认就绪）
    echo ">>> Go  $(go version  2>/dev/null || echo 'N/A')"
    echo ">>> Node $(node --version 2>/dev/null || echo 'N/A')"
    echo ">>> Docker $(docker --version 2>/dev/null || echo 'N/A')"
    # 启动 code-server（如果镜像里有）
    if command -v code-server &>/dev/null; then
      code-server --bind-addr 0.0.0.0:8080 --auth none /home/coder &
    fi
    echo ">>> Workspace ready"
  EOS

  shutdown_script = <<-EOS
    echo "Shutting down..."
  EOS
}

# ---- VS Code Server ----
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
