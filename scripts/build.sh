#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

suite="${SUITE:-stable}"
component="${COMPONENT:-main}"
# Default to `docs/` so you can commit it and serve via GitHub Pages (branch: main, folder: /docs).
repo_out="${REPO_OUT:-$repo_root/docs}"

usage() {
  cat <<EOF
Usage:
  ./scripts/build.sh debs
  ./scripts/build.sh repo

Environment:
  SUITE=$suite
  COMPONENT=$component
  REPO_OUT=$repo_out

Notes:
  - 'debs' builds meta-package .deb files from ./packages/equivs/*.control into the repo root.
  - 'repo' builds an APT repository under REPO_OUT (default: ./public) suitable for GitHub Pages.
EOF
}

need_cmd() {
  local cmd="$1" install_hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing '$cmd'. Install with: $install_hint" >&2
    exit 1
  fi
}

build_debs() {
  local equivs_dir="$repo_root/packages/equivs"

  need_cmd equivs-build "sudo apt-get update && sudo apt-get install -y equivs"

  if [[ ! -d "$equivs_dir" ]]; then
    echo "Missing directory: $equivs_dir" >&2
    exit 1
  fi

  local tmp
  tmp="$(mktemp -d)"
  cleanup() { rm -rf "$tmp"; }
  trap cleanup EXIT

  cp -a "$equivs_dir/." "$tmp/"

  shopt -s nullglob
  local controls=( "$tmp"/*.control )
  if (( ${#controls[@]} == 0 )); then
    echo "No .control files found in $equivs_dir" >&2
    exit 1
  fi

  pushd "$tmp" >/dev/null
  for control in "${controls[@]}"; do
    equivs-build "$control"
  done
  popd >/dev/null

  local debs=( "$tmp"/*.deb )
  if (( ${#debs[@]} == 0 )); then
    echo "No .deb files produced by equivs-build" >&2
    exit 1
  fi

  for deb in "${debs[@]}"; do
    mv -f "$deb" "$repo_root/"
  done

  echo "Wrote .deb files to: $repo_root (sirco-*.deb)"
}

build_repo() {
  need_cmd dpkg-scanpackages "sudo apt-get update && sudo apt-get install -y dpkg-dev"
  need_cmd apt-ftparchive "sudo apt-get update && sudo apt-get install -y apt-utils"

  local pool_dir="$repo_out/pool/$component"
  local dists_dir="$repo_out/dists/$suite/$component"

  rm -rf "$repo_out"
  mkdir -p "$pool_dir"
  touch "$repo_out/.nojekyll"

  build_debs

  shopt -s nullglob
  local debs=( "$repo_root"/sirco-*.deb )
  if (( ${#debs[@]} == 0 )); then
    echo "No sirco-*.deb files found in $repo_root" >&2
    exit 1
  fi

  for deb in "${debs[@]}"; do
    cp -f "$deb" "$pool_dir/"
  done

  # Also include any prebuilt .deb files dropped into ./packages (optional).
  while IFS= read -r -d '' extra_deb; do
    cp -f "$extra_deb" "$pool_dir/"
  done < <(find "$repo_root/packages" -type f -name '*.deb' -print0 2>/dev/null || true)

  # APT expects per-arch indices. Our packages are `Architecture: all`,
  # but clients still fetch both `binary-amd64` and `binary-all` indexes.
  mkdir -p "$dists_dir/binary-all" "$dists_dir/binary-amd64"

  pushd "$repo_out" >/dev/null
  dpkg-scanpackages -m "pool/$component" /dev/null >"dists/$suite/$component/binary-all/Packages"
  gzip -9c "dists/$suite/$component/binary-all/Packages" >"dists/$suite/$component/binary-all/Packages.gz"

  cp -f "dists/$suite/$component/binary-all/Packages" "dists/$suite/$component/binary-amd64/Packages"
  cp -f "dists/$suite/$component/binary-all/Packages.gz" "dists/$suite/$component/binary-amd64/Packages.gz"

  local apt_conf="$repo_out/.apt-ftparchive.conf"
  cat >"$apt_conf" <<EOF
APT::FTPArchive::Release::Origin "Sirco";
APT::FTPArchive::Release::Label "Sirco";
APT::FTPArchive::Release::Suite "$suite";
APT::FTPArchive::Release::Codename "$suite";
APT::FTPArchive::Release::Architectures "amd64 all";
APT::FTPArchive::Release::Components "$component";
APT::FTPArchive::Release::Description "Sirco APT Repo";
EOF

  apt-ftparchive -c "$apt_conf" release "dists/$suite" >"dists/$suite/Release"
  cp -f "dists/$suite/Release" "dists/$suite/InRelease"

  cat >"index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8" />
<title>Sirco APT Repo</title>
<h1>Sirco APT Repo</h1>
<p>This is a static APT repository for <code>sirco-*</code> meta-packages.</p>
<h2>Install</h2>
<pre><code>sudo tee /etc/apt/sources.list.d/sirco.list &lt;&lt;EOF
deb [trusted=yes] https://&lt;owner&gt;.github.io/&lt;repo&gt;/ stable main
EOF

sudo apt-get update
sudo apt-get install sirco-full
</code></pre>
<p>Note: this repo is unsigned; <code>[trusted=yes]</code> is required unless you add signing.</p>
HTML

  popd >/dev/null

  echo "Wrote APT repo to: $repo_out"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    debs) build_debs ;;
    repo) build_repo ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
