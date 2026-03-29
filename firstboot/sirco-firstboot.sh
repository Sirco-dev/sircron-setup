#!/usr/bin/env bash
set -euo pipefail

stamp="/var/lib/sirco/sirco-firstboot.done"

if [[ -f "$stamp" ]]; then
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

mkdir -p "$(dirname "$stamp")"

apt-get update

# Core tools (add/remove to taste)
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  wget \
  git \
  build-essential \
  make \
  snapd

systemctl enable --now snapd.service snapd.socket 2>/dev/null || true

touch "$stamp"
