# Koppie Linux

Custom Arch Linux live ISO with KDE Plasma 6, SDDM, and an offline
Calamares installer. 100% open source, linux-lts kernel, ISO target
under 2 GiB (XZ).

## What's Inside

- `airootfs/` — live system overlay (see BUILD.md §1)
- `grub/`, `syslinux/`, `efiboot/` — bootloader configs
- `packages.x86_64` — package list (120+, Firefox included)
- `pacman.conf`, `profiledef.sh`, `bootstrap_packages` — build config
- `build.sh` — build script
- `GUIDE.md` — general guide and architecture
- `BUILD.md` — download & build instructions

## Quick Start

```bash
git clone https://github.com/maularaihan-git/Koppie-build.git ~/Projects/Koppie-Arch
cd ~/Projects/Koppie-Arch
```

Then follow `BUILD.md` (local repo setup, build, USB flashing with
sha256 verification, hardware testing).

## Specs

| Component | Choice |
|---|---|
| Kernel | linux-lts (+ headers for DKMS/KDM) |
| Desktop | KDE Plasma 6 (plasma-desktop + handpicked, Wayland) |
| Display manager | SDDM (breeze, live autologin) |
| Installer | Calamares 3.4 offline (GRUB BIOS+UEFI) |
| Icons / GTK / Cursor | Papirus-Dark / Orchis-dark / Bibata-Modern-Classic 28 |
| Browser / Office | Firefox / LibreOffice Still + Indonesian |
| License | 100% open source (no firmware/ucode blobs) |
