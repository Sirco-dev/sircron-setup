# sircron-setup

Debian/Ubuntu meta-packages + GitHub Pages–hosted APT repo for the "Sirco" tool packs.

## Meta-packages (equivs)

This repo defines **meta-packages** (mostly empty `.deb` packages that only depend on other packages):

- `sirco-dev` -> dev tooling
- `sirco-gaming` -> gaming tooling
- `sirco-ai` -> python/jupyter basics
- `sirco-full` -> depends on all packs above

Control files live in `packages/equivs/`.

### Build `.deb` files

On a Debian/Ubuntu machine:

```bash
sudo apt-get update
sudo apt-get install -y equivs
./scripts/build-debs.sh
```

Output goes to `dist/`.

### Install a pack locally

```bash
sudo dpkg -i dist/sirco-dev_*_all.deb
sudo apt-get -f install
```

## APT repository (GitHub Pages)

This repo can publish a static APT repository to GitHub Pages.

### Build the repo locally

```bash
sudo apt-get update
sudo apt-get install -y equivs dpkg-dev apt-utils
./scripts/build-apt-repo.sh
```

This writes a static repo to `public/` (with `dists/` + `pool/`).

You can also drop extra prebuilt `.deb` files anywhere under `packages/` and they’ll be included in `pool/main/` when you run `./scripts/build-apt-repo.sh`.

### Use it on a client machine

Replace `<owner>` and `<repo>`:

```bash
sudo tee /etc/apt/sources.list.d/sirco.list <<EOF
deb [trusted=yes] https://<owner>.github.io/<repo>/ stable main
EOF

sudo apt-get update
sudo apt-get install sirco-full
```

Note: the repo is unsigned; `[trusted=yes]` is required unless you add signing.
