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
  - 'repo' builds an APT repository under REPO_OUT (default: ./docs) suitable for GitHub Pages.
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

  rm -rf "$tmp"

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
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Sirco Packages</title>
    <style>
      :root{
        --bg:#f4f1ea;
        --paper:#fffdf8;
        --panel:#ffffff;
        --text:#1f2937;
        --muted:#5f6b7a;
        --accent:#0f766e;
        --accent-soft:#dff5f0;
        --border:#dfd6ca;
        --shadow:0 14px 34px rgba(60, 44, 24, .10);
        --mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;
        --sans:Georgia,"Times New Roman",Times,serif;
        --sans-ui:"Segoe UI",Roboto,Arial,sans-serif;
      }
      *{box-sizing:border-box}
      body{
        margin:0;
        font-family:var(--sans-ui);
        color:var(--text);
        background:
          radial-gradient(900px 520px at top left, rgba(201, 179, 140, .20), transparent 60%),
          linear-gradient(180deg, #f8f5ef, var(--bg));
        min-height:100vh;
      }
      .wrap{max-width:1040px;margin:0 auto;padding:40px 20px 72px}
      .hero{
        display:flex;gap:18px;align-items:flex-start;justify-content:space-between;flex-wrap:wrap;
        padding:28px;border:1px solid var(--border);border-radius:22px;
        background:
          linear-gradient(135deg, rgba(15,118,110,.08), rgba(255,255,255,.70)),
          var(--paper);
        box-shadow:var(--shadow);
      }
      h1{
        margin:0;
        font-family:var(--sans);
        font-size:42px;
        font-weight:700;
        letter-spacing:.2px;
      }
      .sub{margin:10px 0 0;color:var(--muted);line-height:1.6;max-width:56ch}
      .badge{
        font-family:var(--mono);
        font-size:12px;
        color:var(--accent);
        background:var(--accent-soft);
        border:1px solid rgba(15,118,110,.18);
        padding:8px 12px;
        border-radius:999px;
        white-space:nowrap;
      }
      .grid{display:grid;grid-template-columns:1fr;gap:16px;margin-top:18px}
      @media (min-width:920px){.grid{grid-template-columns:1.15fr .85fr}}
      .card{
        border:1px solid var(--border);
        border-radius:20px;
        background:var(--panel);
        box-shadow:var(--shadow);
      }
      .card h2{
        margin:0;
        padding:18px 20px;
        border-bottom:1px solid var(--border);
        font-family:var(--sans);
        font-size:24px;
        font-weight:700;
      }
      .card .body{padding:16px 18px}
      .code{
        background:#fbfaf7;
        border:1px solid var(--border);
        border-radius:16px;
        padding:16px;
        overflow:auto;
        font-family:var(--mono);
        font-size:13px;
        line-height:1.45;
      }
      .row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
      .btn{
        appearance:none;
        border:1px solid rgba(15,118,110,.20);
        background:var(--accent);
        color:#fff;
        padding:10px 14px;
        border-radius:999px;
        font-weight:600;
        cursor:pointer;
      }
      .btn:hover{filter:brightness(.95)}
      .muted{color:var(--muted);font-size:14px;line-height:1.6;margin:10px 0 0}
      .list{margin:0;padding-left:20px;color:var(--muted);font-size:14px;line-height:1.7}
      a{color:var(--accent)}
      .k{color:var(--text)}
      .warn{
        margin-top:10px;
        background:#fff8ea;
        border:1px solid #ecd39d;
        padding:12px 14px;
        border-radius:14px;
        color:#6d5520;
        font-size:13px;
      }
      .packages{
        display:grid;
        grid-template-columns:1fr;
        gap:10px;
        margin-top:14px;
      }
      .pkg{
        border:1px solid var(--border);
        border-radius:14px;
        padding:12px 14px;
        background:#fcfbf8;
      }
      .pkg strong{
        display:block;
        font-family:var(--mono);
        font-size:14px;
        margin-bottom:4px;
      }
      .footer{
        margin-top:18px;
        color:var(--muted);
        font-size:13px;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="hero">
        <div>
          <h1>Sirco Packages</h1>
          <p class="sub">Official APT repository for the Sirco distro package sets. Use this repository to install the public meta-packages for desktop, development, gaming, AI, and full workstation setups.</p>
        </div>
        <div class="badge">https://sirco-dev.github.io/sircron-setup/</div>
      </div>

      <div class="grid">
        <div class="card">
          <h2>Add Repository</h2>
          <div class="body">
            <div class="row" style="justify-content:space-between">
              <div class="muted" style="margin:0">Run this on any Debian or Ubuntu system:</div>
              <button class="btn" id="copy">Copy</button>
            </div>
            <pre class="code" id="snippet"><code>sudo tee /etc/apt/sources.list.d/sirco.list >/dev/null &lt;&lt;'EOF'
deb [trusted=yes] https://sirco-dev.github.io/sircron-setup/ stable main
EOF
sudo apt-get update
sudo apt-get install -y sirco-full</code></pre>
            <div class="warn">Note: this repo is unsigned; <code>[trusted=yes]</code> is required unless you add signing.</div>
          </div>
        </div>

        <div class="card">
          <h2>Available Packs</h2>
          <div class="body">
            <div class="packages">
              <div class="pkg">
                <strong>sirco-desktop</strong>
                GNOME desktop, login manager, and core desktop applications.
              </div>
              <div class="pkg">
                <strong>sirco-dev</strong>
                Development tools and build essentials.
              </div>
              <div class="pkg">
                <strong>sirco-gaming</strong>
                Gaming tools such as Lutris, Wine, and related utilities.
              </div>
              <div class="pkg">
                <strong>sirco-ai</strong>
                Python, notebooks, and common AI/data packages.
              </div>
              <div class="pkg">
                <strong>sirco-full</strong>
                Installs the full Sirco package set.
              </div>
            </div>
            <p class="footer">Repository files: <a href="./dists/stable/Release">Release</a> and <a href="./dists/stable/main/binary-amd64/Packages">Packages</a>.</p>
          </div>
        </div>
      </div>
    </div>

    <script>
      (function () {
        const btn = document.getElementById('copy');
        const snippet = document.getElementById('snippet').innerText.trim();
        btn.addEventListener('click', async () => {
          try {
            await navigator.clipboard.writeText(snippet);
            btn.textContent = 'Copied';
            setTimeout(() => (btn.textContent = 'Copy'), 1200);
          } catch {
            btn.textContent = 'Copy failed';
            setTimeout(() => (btn.textContent = 'Copy'), 1200);
          }
        });
      })();
    </script>
  </body>
</html>
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
