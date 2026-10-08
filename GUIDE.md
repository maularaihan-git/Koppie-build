# Koppie Linux — General Guide

## 1. Project Layout Rule

Every new distro/project MUST live inside `~/Projects/` first
(example: `~/Projects/Koppie-Arch`). Never scatter files in `~`
or `/tmp`.

## 2. Architecture

- **Base**: Arch Linux, rolling release with conservative package
  choices (linux-lts, LibreOffice Still) — "stable-flavored rolling".
- **Live user**: created on first boot by `koppie-live-user.service`
  (user `live`, password `koppie`). SDDM autologin enabled.
- **Theming**: Papirus-Dark icons, Orchis-dark GTK + look-and-feel,
  Bibata-Modern-Classic cursor (size 28), Koppie wallpaper with
  KDE metadata (`Koppie/contents/Images[_dark]/5120x2880.png`).
- **Installer**: Calamares 3.4, fully offline (local squashfs source),
  Koppie branding, `removeuser` + `try_remove` clean live-only
  packages post-install.
- **Custom repo**: KDM (driver manager) + KUM (update manager) and
  AUR helpers come from the `[koppie]` local repo
  (https://github.com/maularaihan-git/koppie-repo).
- **100% open source**: no linux-firmware, no ucode blobs (deliberate).
  Wi-Fi is handled by Koppie's internal tools; KDM installs extra
  drivers online (cable/tether once) via DKMS.

## 3. Key Conventions

- `packages.x86_64`: one package name per line, no comments
  (mkarchiso requirement).
- Files owned by packages must NOT be placed in `airootfs/`
  (pacstrap "exists in filesystem" conflict). Override them in
  `airootfs/root/customize_airootfs.sh` instead.
- Skel configs (`/etc/skel/`) must contain zero absolute paths
  (`/home/...`) and zero host-specific IDs (e.g. Plasma activityId).
- Every USB flash MUST be sha256-verified before boot. A `dd`
  finishing in seconds for a 1.7 GB image is lying (cache) —
  always use `conv=fsync` + `sync` + hash check.
