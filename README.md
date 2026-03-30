# sircron-setup

Debian/Ubuntu meta-packages + GitHub Pages–hosted APT repo for the "Sirco" tool packs.

Packages:
- `sirco-desktop` for the GNOME desktop, display manager, and core desktop apps
- `sirco-dev` for development tools
- `sirco-gaming` for gaming tools
- `sirco-ai` for AI/data/notebook tools
- `sirco-full` for the full non-desktop package set
- `sirco-all-desktop` for everything including the desktop

Build locally (Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y equivs dpkg-dev apt-utils
./scripts/build.sh debs
./scripts/build.sh repo
```

`./scripts/build.sh repo` writes the static APT repo into `docs/` by default.

GitHub Pages setup (manual):
- Settings → Pages → Build and deployment → Source: **Deploy from a branch**
- Branch: `main`
- Folder: `/docs`

```bash
sudo tee /etc/apt/sources.list.d/sirco.list >/dev/null <<'EOF'
deb [trusted=yes] https://sirco-dev.github.io/sircron-setup/ stable main
EOF
sudo apt-get update
sudo apt-get install -y sirco-all-desktop
```

Desktop-only install:

```bash
sudo apt-get install -y sirco-desktop
```

Full non-desktop install:

```bash
sudo apt-get install -y sirco-full
```

If `apt-get update` 404s, verify these URLs exist:

- `https://sirco-dev.github.io/sircron-setup/dists/stable/Release`
- `https://sirco-dev.github.io/sircron-setup/dists/stable/main/binary-amd64/Packages`

If install fails due to Steam/i386 dependencies, install without recommended packages:

```bash
sudo apt-get install -y --no-install-recommends sirco-all-desktop
```

`sirco-desktop` includes a package post-install step that safely tries to:
- set the system default target to `graphical.target`
- enable `gdm3`
- enable `NetworkManager`
- write `/etc/sirco/desktop-profile`
