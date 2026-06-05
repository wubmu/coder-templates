# 占位 Terraform 配置 — 仅用于 terraform providers mirror
# 列出所有模板中用到的 provider，方便一次性预下载
# 新增模板如有新 provider，在此加一行

terraform {
  required_version = ">= 1.5"
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
