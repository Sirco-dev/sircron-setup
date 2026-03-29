#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${OUT_DIR:-$repo_root/dist}"

if ! command -v equivs-build >/dev/null 2>&1; then
  echo "Missing 'equivs-build'. Install it with: sudo apt-get update && sudo apt-get install -y equivs" >&2
  exit 1
fi

mkdir -p "$out_dir"

maintainer_name="Sirco Team"
maintainer_email="info@gace.space"
legal_email="legal@gace.space"

deps_sirco_dev=(
  build-essential make pkg-config cmake ninja-build
  git git-lfs openssh-client
  curl wget ca-certificates gnupg lsb-release software-properties-common
  zip unzip tar gzip bzip2 xz-utils
  jq ripgrep fd-find fzf tree less
  man-db manpages manpages-dev
  vim "|" neovim tmux shellcheck
  python3.12 "|" python3.11 "|" python3.10 "|" python3 python-is-python3 "|" python3
  python3-pip python3-venv python3-dev python3-full "|" python3 pipx virtualenv
  nodejs npm yarnpkg
  openjdk-21-jdk "|" openjdk-17-jdk "|" default-jdk openjdk-21-jre "|" openjdk-17-jre "|" default-jre maven gradle
  golang-go rustc cargo
  ruby-full
  php-cli composer
  sqlite3 postgresql-client default-mysql-client "|" mysql-client redis-tools
  docker.io docker-compose-plugin "|" docker-compose
)

deps_sirco_ai=(
  python3.12 "|" python3.11 "|" python3.10 "|" python3 python-is-python3 "|" python3
  python3-pip python3-venv python3-dev pipx
  jupyter-notebook "|" jupyter
  python3-numpy python3-scipy python3-pandas python3-matplotlib python3-skimage
  python3-requests python3-yaml
)

deps_sirco_gaming=(
  steam-installer "|" steam lutris wine winetricks gamemode
  mesa-utils vulkan-tools
)

deps_sirco_full=(
  sirco-dev sirco-gaming sirco-ai
)

wrap_depends() {
  local -a deps=("$@")
  local out="" line_len=0 token
  for token in "${deps[@]}"; do
    if [[ "$token" == "|" ]]; then
      out+=" |"
      line_len=$((line_len + 2))
      continue
    fi
    if [[ -z "$out" ]]; then
      out+="$token"
      line_len=${#token}
      continue
    fi
    # Wrap roughly at ~78 chars for readability in control files.
    if (( line_len + 2 + ${#token} > 78 )); then
      out+=",\n $token"
      line_len=$((1 + ${#token}))
    else
      out+=", $token"
      line_len=$((line_len + 2 + ${#token}))
    fi
  done
  printf "%b" "$out"
}

write_control() {
  local path="$1"
  local package="$2"
  local version="$3"
  local short_desc="$4"
  local long_desc="$5"
  shift 5
  local depends
  depends="$(wrap_depends "$@")"

  cat >"$path" <<EOF
Section: misc
Priority: optional
Standards-Version: 3.9.2

Package: $package
Version: $version
Maintainer: $maintainer_name <$maintainer_email>
Depends: $depends
Description: $short_desc
 $long_desc
 Legal contact: $legal_email
EOF
}

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

pushd "$tmp" >/dev/null
write_control "$tmp/sirco-dev.control" "sirco-dev" "1.0" \
  "Sirco Development Pack (meta-package)" \
  "Installs a broad development toolbox (Debian/Ubuntu)." \
  "${deps_sirco_dev[@]}"

write_control "$tmp/sirco-gaming.control" "sirco-gaming" "1.0" \
  "Sirco Gaming Pack (meta-package)" \
  "Installs common gaming tools (Debian/Ubuntu)." \
  "${deps_sirco_gaming[@]}"

write_control "$tmp/sirco-ai.control" "sirco-ai" "1.0" \
  "Sirco AI Pack (meta-package)" \
  "Installs a lightweight Python AI/notebook starter set (Debian/Ubuntu)." \
  "${deps_sirco_ai[@]}"

write_control "$tmp/sirco-full.control" "sirco-full" "1.0" \
  "Sirco Full Pack (meta-package)" \
  "Installs all Sirco packs (dev + gaming + ai)." \
  "${deps_sirco_full[@]}"

equivs-build "$tmp/sirco-dev.control"
equivs-build "$tmp/sirco-gaming.control"
equivs-build "$tmp/sirco-ai.control"
equivs-build "$tmp/sirco-full.control"
popd >/dev/null

shopt -s nullglob
for deb in "$tmp"/*.deb; do
  mv -f "$deb" "$out_dir/"
done

echo "Wrote .deb files to: $out_dir"
