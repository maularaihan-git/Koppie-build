# Koppie Linux — Build Guide

## 1. Project Tree

```
Koppie-Arch/
├── airootfs/              # Root overlay (configs, themes, scripts)
│   ├── etc/skel/          # Default user configs (panel, theme, neofetch)
│   ├── etc/sddm.conf.d/   # SDDM (breeze + live autologin)
│   ├── etc/systemd/       # Units (koppie-live-user, wants)
│   ├── etc/sudoers.d/     # Live sudo rules
│   ├── root/customize_airootfs.sh  # Post-install hook (auto-run)
│   ├── usr/local/bin/     # Helpers (koppie-live-user)
│   ├── usr/share/wallpapers/Koppie/  # Wallpaper + metadata.json
│   └── usr/share/koppie/overrides/   # Staging for package-owned files
├── grub/                  # GRUB config (linux-lts kernel)
├── syslinux/              # Syslinux config (BIOS)
├── efiboot/               # UEFI boot entries
├── packages.x86_64        # Package list (plain names only)
├── pacman.conf            # Pacman config + [koppie] local repo
├── profiledef.sh          # Profile (name, label, GRUB modes, XZ)
├── build.sh               # Anti-sleep build wrapper (systemd-inhibit)
└── bootstrap_packages     # Bootstrap packages
```

NOT in this repo: `work/`, `out/`, `build-*.log`, `audit_report.md`.

## 2. Build Prerequisites

- Arch Linux x86_64 build host
- `sudo pacman -S --needed archiso mkinitcpio-archiso base-devel git`
- Passwordless sudo recommended during build
- Internet (first build downloads ~1 GB)
- At least 15 GB free disk

## 3. Local Repo [koppie]

Custom/AUR packages (calamares, KDM, KUM, yay, neofetch, bibata,
tela, splix, configs) come from the local repo registered in
`pacman.conf`:

```
[koppie]
SigLevel = Optional TrustAll
Server = file:///home/raihan/koppie-repo/x86_64
```

The repo DB (`koppie.db.tar.gz`) must contain every custom package
BEFORE building. Add one with:

```bash
cp foo-1.0-1-any.pkg.tar.zst ~/koppie-repo/x86_64/
cd ~/koppie-repo/x86_64
repo-add koppie.db.tar.gz foo-1.0-1-any.pkg.tar.zst
```

## 4. Build

```bash
cd ~/Projects/Koppie-Arch
./build.sh
```

This checks sudo, runs `mkarchiso -v .` inside `systemd-inhibit`
(sleep/suspend blocked during build), saves a full log
(`build-YYYYMMDD-HHMMSS.log`), and lists `out/`.

Result: `out/koppie-YYYY.MM.DD-x86_64.iso` (±1.7 GiB).

## 5. Flash USB + Verify (MANDATORY)

```bash
sudo dd if=out/koppie-2026.10.08-x86_64.iso of=/dev/sdX bs=4M conv=fsync status=progress
sync
sudo head -c $(stat -c %s out/koppie-2026.10.08-x86_64.iso) /dev/sdX | sha256sum
sha256sum out/koppie-2026.10.08-x86_64.iso
```

Both hashes MUST match. Replace `/dev/sdX` with the real USB device
(check `lsblk` — wrong device = DATA LOSS).

## 6. Test Checklist (live session, no install)

1. GRUB menu shows, kernel boots, no kernel panic
2. SDDM shows Koppie wallpaper + autologin works
3. Desktop shows Koppie wallpaper, panel, Kickoff
4. `neofetch` shows Koppie ASCII + cyan
5. Open Calamares from the desktop icon (one trust Continue click)
6. Open KDM + KUM (both must launch)
7. `live:koppie` / `root:koppie` work on TTY
