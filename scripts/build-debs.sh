#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
equivs_dir="$repo_root/packages/equivs"
out_dir="${OUT_DIR:-$repo_root/dist}"

if ! command -v equivs-build >/dev/null 2>&1; then
  echo "Missing 'equivs-build'. Install it with: sudo apt-get update && sudo apt-get install -y equivs" >&2
  exit 1
fi

if [[ ! -d "$equivs_dir" ]]; then
  echo "Missing directory: $equivs_dir" >&2
  exit 1
fi

mkdir -p "$out_dir"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

cp -a "$equivs_dir/." "$tmp/"

shopt -s nullglob
controls=( "$tmp"/*.control )
if (( ${#controls[@]} == 0 )); then
  echo "No .control files found in $equivs_dir" >&2
  exit 1
fi

pushd "$tmp" >/dev/null
for control in "${controls[@]}"; do
  equivs-build "$control"
done
popd >/dev/null

debs=( "$tmp"/*.deb )
if (( ${#debs[@]} == 0 )); then
  echo "No .deb files produced by equivs-build" >&2
  exit 1
fi

for deb in "${debs[@]}"; do
  mv -f "$deb" "$out_dir/"
done

echo "Wrote .deb files to: $out_dir"
