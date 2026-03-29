#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

suite="${SUITE:-stable}"
component="${COMPONENT:-main}"
repo_out="${REPO_OUT:-$repo_root/public}"
pool_dir="$repo_out/pool/$component"
dists_dir="$repo_out/dists/$suite/$component"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "Missing 'dpkg-scanpackages'. Install with: sudo apt-get install -y dpkg-dev" >&2
  exit 1
fi
if ! command -v apt-ftparchive >/dev/null 2>&1; then
  echo "Missing 'apt-ftparchive'. Install with: sudo apt-get install -y apt-utils" >&2
  exit 1
fi

rm -rf "$repo_out"
mkdir -p "$pool_dir"
touch "$repo_out/.nojekyll"

# Build the meta-package .debs into dist/
"$repo_root/scripts/build-debs.sh"

shopt -s nullglob
# Pick up the meta-packages we build (typically `sirco-*_1.0_all.deb`).
debs=( "$repo_root"/sirco-*.deb )
if (( ${#debs[@]} == 0 )); then
  echo "No .deb files found in $repo_root" >&2
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

dpkg-scanpackages -m "pool/$component" /dev/null >"$dists_dir/binary-all/Packages"
gzip -9c "$dists_dir/binary-all/Packages" >"$dists_dir/binary-all/Packages.gz"

cp -f "$dists_dir/binary-all/Packages" "$dists_dir/binary-amd64/Packages"
cp -f "$dists_dir/binary-all/Packages.gz" "$dists_dir/binary-amd64/Packages.gz"

apt_conf="$repo_out/.apt-ftparchive.conf"
cat >"$apt_conf" <<EOF
APT::FTPArchive::Release::Origin "Sirco";
APT::FTPArchive::Release::Label "Sirco";
APT::FTPArchive::Release::Suite "$suite";
APT::FTPArchive::Release::Codename "$suite";
APT::FTPArchive::Release::Architectures "amd64 all";
APT::FTPArchive::Release::Components "$component";
APT::FTPArchive::Release::Description "Sirco APT Repo";
EOF

apt-ftparchive -c "$apt_conf" release "$repo_out/dists/$suite" >"$repo_out/dists/$suite/Release"

cat >"$repo_out/index.html" <<'HTML'
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
sudo apt-get install sirco-dev
</code></pre>
<p>Note: this repo is unsigned; <code>[trusted=yes]</code> is required unless you add signing.</p>
HTML

echo "Wrote APT repo to: $repo_out"
