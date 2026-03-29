#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (or via sudo): sudo $0" >&2
  exit 1
fi

install -m 0755 "$repo_root/firstboot/sirco-firstboot.sh" /usr/local/sbin/sirco-firstboot
install -m 0644 "$repo_root/firstboot/sirco-firstboot.service" /etc/systemd/system/sirco-firstboot.service

systemctl daemon-reload
systemctl enable sirco-firstboot.service

echo "Installed and enabled: sirco-firstboot.service"
echo "To run now: systemctl start sirco-firstboot.service"
