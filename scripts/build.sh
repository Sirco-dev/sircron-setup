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
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Sirco APT Repo</title>
    <style>
      :root{
        --bg:#0b1220;
        --panel:#0f1a2e;
        --panel2:#0c1629;
        --text:#e6eefc;
        --muted:#a9b8d6;
        --accent:#7c5cff;
        --accent2:#22d3ee;
        --border:rgba(255,255,255,.10);
        --shadow:0 20px 60px rgba(0,0,0,.45);
        --mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;
        --sans:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,"Noto Sans",Arial,"Apple Color Emoji","Segoe UI Emoji";
      }
      *{box-sizing:border-box}
      body{
        margin:0;
        font-family:var(--sans);
        color:var(--text);
        background:
          radial-gradient(1200px 800px at 20% 10%, rgba(124,92,255,.25), transparent 60%),
          radial-gradient(900px 700px at 85% 25%, rgba(34,211,238,.18), transparent 55%),
          linear-gradient(180deg, var(--bg), #070b14);
        min-height:100vh;
      }
      .wrap{max-width:980px;margin:0 auto;padding:48px 20px 72px}
      .hero{
        display:flex;gap:18px;align-items:flex-start;justify-content:space-between;flex-wrap:wrap;
        padding:22px 22px 18px;border:1px solid var(--border);border-radius:18px;
        background:linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.02));
        box-shadow:var(--shadow);
      }
      h1{margin:0;font-size:28px;letter-spacing:.2px}
      .sub{margin:6px 0 0;color:var(--muted);line-height:1.45}
      .badge{
        font-family:var(--mono);font-size:12px;color:rgba(230,238,252,.92);
        background:linear-gradient(90deg, rgba(124,92,255,.35), rgba(34,211,238,.25));
        border:1px solid rgba(255,255,255,.16);
        padding:8px 10px;border-radius:999px;white-space:nowrap;
      }
      .grid{display:grid;grid-template-columns:1fr;gap:14px;margin-top:18px}
      @media (min-width:900px){.grid{grid-template-columns:1.25fr .75fr}}
      .card{
        border:1px solid var(--border);border-radius:18px;background:rgba(15,26,46,.72);
        box-shadow:0 18px 40px rgba(0,0,0,.35);
      }
      .card h2{margin:0;padding:16px 18px;border-bottom:1px solid var(--border);font-size:15px;color:rgba(230,238,252,.92)}
      .card .body{padding:16px 18px}
      .code{
        background:rgba(8,13,24,.65);
        border:1px solid rgba(255,255,255,.10);
        border-radius:14px;
        padding:14px 14px;
        overflow:auto;
        font-family:var(--mono);
        font-size:13px;
        line-height:1.45;
      }
      .row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
      .btn{
        appearance:none;border:1px solid rgba(255,255,255,.16);
        background:linear-gradient(180deg, rgba(124,92,255,.35), rgba(124,92,255,.18));
        color:var(--text);padding:10px 12px;border-radius:12px;font-weight:600;
        cursor:pointer;
      }
      .btn:hover{border-color:rgba(255,255,255,.26)}
      .muted{color:var(--muted);font-size:13px;line-height:1.5;margin:10px 0 0}
      .list{margin:0;padding-left:18px;color:var(--muted);font-size:13px;line-height:1.55}
      a{color:#b8c8ff}
      .k{color:rgba(230,238,252,.92)}
      .warn{
        margin-top:10px;
        background:rgba(255,177,66,.10);
        border:1px solid rgba(255,177,66,.25);
        padding:10px 12px;border-radius:12px;
        color:rgba(255,230,200,.95);
        font-size:13px;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="hero">
        <div>
          <h1>Sirco APT Repo</h1>
          <p class="sub">Static APT repository for <span class="k">sirco-*</span> meta-packages.</p>
        </div>
        <div class="badge">https://sirco-dev.github.io/sircron-setup/</div>
      </div>

      <div class="grid">
        <div class="card">
          <h2>Install</h2>
          <div class="body">
            <div class="row" style="justify-content:space-between">
              <div class="muted" style="margin:0">Copy/paste into a terminal:</div>
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
          <h2>Troubleshooting</h2>
          <div class="body">
            <p class="muted" style="margin-top:0">If <code>apt-get update</code> 404s, check these URLs exist:</p>
            <ul class="list">
              <li><a href="./dists/stable/Release">./dists/stable/Release</a></li>
              <li><a href="./dists/stable/main/binary-amd64/Packages">./dists/stable/main/binary-amd64/Packages</a></li>
            </ul>
            <p class="muted">GitHub Pages must be set to serve from <code>main</code> + <code>/docs</code>.</p>
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
