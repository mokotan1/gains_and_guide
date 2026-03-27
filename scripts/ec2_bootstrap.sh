#!/usr/bin/env bash
# EC2 초기 구축: Docker 설치 및 (선택) backend_ai 기동 준비.
# 사용: sudo bash ec2_bootstrap.sh
# 지원: Amazon Linux 2 / Amazon Linux 2023, Ubuntu 22.04+

set -euo pipefail

log() { printf '%s\n' "$*"; }

if [[ "${EUID:-0}" -ne 0 ]]; then
  log "root 권한으로 실행하세요: sudo bash $0"
  exit 1
fi

. /etc/os-release

install_docker_amzn2023() {
  dnf install -y docker
  systemctl enable --now docker
  dnf install -y docker-compose-plugin 2>/dev/null || true
}

install_docker_amzn2() {
  yum install -y docker
  systemctl enable --now docker
}

install_docker_ubuntu() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl docker.io
  apt-get install -y docker-compose-v2 2>/dev/null || true
  systemctl enable --now docker
  if ! docker compose version >/dev/null 2>&1; then
    log "경고: docker compose 가 없습니다. Ubuntu 에서 apt install docker-compose-v2 를 시도하세요."
  fi
}

case "${ID}-${VERSION_ID:-}" in
  amzn-2023*)
    install_docker_amzn2023
    ;;
  amzn-2*)
    install_docker_amzn2
    ;;
  ubuntu-*)
    install_docker_ubuntu
    ;;
  *)
    log "지원하지 않는 OS: ID=$ID VERSION_ID=${VERSION_ID:-unknown}"
    log "수동으로 Docker를 설치한 뒤 backend_ai 디렉터리에서 docker compose 를 실행하세요."
    exit 1
    ;;
esac

# 일반 사용자가 docker 쓰도록 (로그인한 사용자 기준; sudo로 실행 시 SUDO_USER)
if [[ -n "${SUDO_USER:-}" ]]; then
  usermod -aG docker "$SUDO_USER"
  log "사용자 '$SUDO_USER' 를 docker 그룹에 추가했습니다. SSH 재접속 후 docker 를 sudo 없이 사용할 수 있습니다."
fi

log "Docker 설치 완료: $(docker --version 2>/dev/null || true)"
log "다음: backend_ai 와 .env(GROQ_API_KEY) 를 서버에 두고 해당 디렉터리에서"
log "  docker compose -f docker-compose.prod.yml up -d --build"
