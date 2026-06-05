#!/usr/bin/env bash
# Coder workspace dind 启动脚本
# 在容器启动时运行 dockerd，然后执行传入的命令
set -e

DOCKER_PID_FILE=/tmp/dockerd.pid
DOCKER_SOCK=/var/run/docker.sock

start_dockerd() {
  echo "[dind] 启动 dockerd ..."

  # 清理残留
  rm -f "${DOCKER_PID_FILE}"

  # 以 root 启动 dockerd（需要 privileged）
  sudo containerd &
  sudo dockerd \
    --data-root /home/coder/.docker/data \
    --exec-root /home/coder/.docker/exec \
    --pidfile "${DOCKER_PID_FILE}" \
    --storage-driver overlay2 \
    --iptables=false \
    --ip6tables=false \
    --log-level warn \
    &>/tmp/dockerd.log &

  # 等待 docker 就绪
  local waited=0
  until sudo docker info &>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if [ $waited -gt 30 ]; then
      echo "[dind] 超时！dockerd 启动日志:"
      cat /tmp/dockerd.log
      exit 1
    fi
  done
  echo "[dind] dockerd 就绪 (${waited}s)"
}

stop_dockerd() {
  echo "[dind] 停止 dockerd ..."
  if [ -f "${DOCKER_PID_FILE}" ]; then
    sudo kill "$(cat "${DOCKER_PID_FILE}")" 2>/dev/null || true
  fi
  sudo killall containerd 2>/dev/null || true
  echo "[dind] 已停止"
}

# 捕获退出信号，清理 dockerd
trap stop_dockerd EXIT INT TERM

# 启动 dind
start_dockerd

# 执行 Coder agent 传入的命令
exec "$@"
