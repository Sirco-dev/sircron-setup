#!/bin/sh
set -eu

state_dir="/var/lib/sirco"
state_file="$state_dir/sirco-desktop-setup.done"

mkdir -p "$state_dir" /etc/sirco

if [ ! -f /etc/sirco/desktop-profile ]; then
  cat > /etc/sirco/desktop-profile <<'EOF'
DESKTOP=gnome
PACKAGE=sirco-desktop
EOF
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl set-default graphical.target >/dev/null 2>&1 || true
  systemctl enable gdm3.service >/dev/null 2>&1 || true
  systemctl enable NetworkManager.service >/dev/null 2>&1 || true
fi

touch "$state_file"
exit 0
