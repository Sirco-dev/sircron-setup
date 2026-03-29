# sircron-setup

Debian/Ubuntu meta-packages + GitHub Pages–hosted APT repo for the "Sirco" tool packs.

Build locally (Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y equivs dpkg-dev apt-utils
./scripts/build.sh debs
./scripts/build.sh repo
```

`./scripts/build.sh repo` writes the static APT repo into `docs/` by default.

GitHub Pages options:
- **Manual (no Actions):** Settings → Pages → Build and deployment → Source: **Deploy from a branch** → Branch: `main` → Folder: `/docs`
- **GitHub Actions:** Settings → Pages → Source: **GitHub Actions** (workflow: `.github/workflows/pages.yml`)

```bash
sudo tee /etc/apt/sources.list.d/sirco.list >/dev/null <<'EOF'
deb [trusted=yes] https://sirco-dev.github.io/sircron-setup/ stable main
EOF
sudo apt-get update
sudo apt-get install -y sirco-full
```

If `apt-get update` 404s, verify these URLs exist:

- `https://sirco-dev.github.io/sircron-setup/dists/stable/Release`
- `https://sirco-dev.github.io/sircron-setup/dists/stable/main/binary-amd64/Packages`
