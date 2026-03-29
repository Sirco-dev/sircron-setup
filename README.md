# sircron-setup

Debian/Ubuntu meta-packages + GitHub Pages–hosted APT repo for the "Sirco" tool packs.

Build locally (Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y equivs dpkg-dev apt-utils
./scripts/build.sh debs
./scripts/build.sh repo
```

Make sure GitHub Pages is enabled for this repo (Settings → Pages → Source: **GitHub Actions**) and that the workflow ran.

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
