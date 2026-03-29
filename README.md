# sircron-setup

Debian/Ubuntu meta-packages + first-boot setup for the "Sirco" tool packs.

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

## First boot setup (systemd)

Installs some baseline tools (including `make` and `snapd`) once, on first boot.

- Script: `firstboot/sirco-firstboot.sh`
- Unit: `firstboot/sirco-firstboot.service`

Install + enable:

```bash
sudo ./scripts/install-firstboot.sh
```
