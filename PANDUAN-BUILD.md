# Koppie Linux — Panduan Build (Formal)

Dokumen ini menjelaskan cara membangun ISO Koppie Linux dari source,
cara mengunduh folder project, serta ringkasan arsitektur.

## 1. Struktur Folder Project

```
Koppie-Arch/
├── airootfs/              # Overlay root filesystem (config, tema, script)
│   ├── etc/skel/          # Config default user (panel, tema, wallpaper, neofetch)
│   ├── etc/sddm.conf.d/   # Konfigurasi SDDM (breeze + autologin live)
│   ├── etc/systemd/       # Unit systemd (koppie-live-user, wants)
│   ├── etc/sudoers.d/     # Aturan sudo live
│   ├── etc/plymouth/      # (diisi via customize, lihat bawah)
│   ├── root/customize_airootfs.sh  # Script pasca-install (jalan otomatis)
│   ├── usr/local/bin/     # Script bantu (koppie-live-user)
│   ├── usr/share/wallpapers/Koppie/  # Wallpaper resmi + metadata.json
│   └── usr/share/koppie/overrides/   # Staging file milik paket (plymouth)
├── grub/                  # Konfigurasi GRUB (kernel linux-lts)
├── syslinux/              # Konfigurasi Syslinux (BIOS)
├── efiboot/               # Konfigurasi boot UEFI
├── packages.x86_64        # Daftar paket (satu nama per baris, tanpa komentar)
├── pacman.conf            # Konfigurasi pacman + repo lokal [koppie]
├── profiledef.sh          # Definisi profil (nama, label, bootmode, kompresi XZ)
├── build.sh               # Script build anti-tidur (systemd-inhibit + mkarchiso)
├── PANDUAN.md             # Panduan umum (file ini adalah PANDUAN-BUILD)
└── bootstrap_packages     # Paket bootstrap
```

File yang TIDAK ikut ke repo: `work/`, `out/`, `build-*.log`, `audit_report.md`.

## 2. Prasyarat Build

- Arch Linux x86_64 (host build)
- Paket host: `archiso`, `mkinitcpio-archiso`, `base-devel`, `git`
- Akses sudo (passwordless disarankan selama build)
- Koneksi internet (pertama kali, untuk download paket ~1 GB)
- Ruang disk kosong minimal 15 GB

```bash
sudo pacman -S --needed archiso mkinitcpio-archiso base-devel git
```

## 3. Menyiapkan Local Repo [koppie]

Paket custom/AUR (calamares, KDM, KUM, yay, neofetch, bibata, tela,
splix, lightdm-kde-greeter, koppie-welcome, *-config) berasal dari
local repo yang sudah terdaftar di `pacman.conf`:

```
[koppie]
SigLevel = Optional TrustAll
Server = file:///home/raihan/koppie-repo/x86_64
```

Pastikan database repo (`koppie.db.tar.gz`) sudah berisi semua paket
sebelum build. Cara menambah paket:

```bash
cp paket-1.0.0-1-any.pkg.tar.zst ~/koppie-repo/x86_64/
cd ~/koppie-repo/x86_64
repo-add koppie.db.tar.gz paket-1.0.0-1-any.pkg.tar.zst
```

## 4. Menjalankan Build

```bash
cd ~/Projects/Koppie-Arch
./build.sh
```

Script akan: cek sudo → menjalankan `mkarchiso -v .` di dalam
`systemd-inhibit` (sleep/suspend diblokir selama build) → menyimpan
log `build-YYYYMMDD-HHMMSS.log` → menampilkan isi `out/`.

Hasil: `out/koppie-YYYY.MM.DD-x86_64.iso` (±1,7 GiB).

## 5. Menulis ke USB + Verifikasi (WAJIB)

```bash
sudo dd if=out/koppie-2026.10.08-x86_64.iso of=/dev/sdX bs=4M conv=fsync status=progress
sync
sudo head -c $(stat -c %s out/koppie-2026.10.08-x86_64.iso) /dev/sdX | sha256sum
sha256sum out/koppie-2026.10.08-x86_64.iso
```

Kedua hash HARUS sama persis. Aturan praktis: `dd` yang selesai
di bawah 1 menit untuk ISO 1,7 GB = bohong (cache), JANGAN cabut.
Gunakan `conv=fsync` + `sync` + verifikasi sha256. Ganti `/dev/sdX`
dengan device USB yang benar (cek via `lsblk`). SALAH DEVICE =
DATA HILANG.

## 6. Alur Konfigurasi Penting ( ringkas )

- **Live user**: dibuat saat boot pertama oleh
  `koppie-live-user.service` (user `live`, password `koppie`).
- **Autologin**: SDDM (`etc/sddm.conf.d/koppie.conf`).
- **Tema**: Papirus-Dark (ikon), Orchis-dark (GTK), Bibata-Modern-Classic 28
  (kursor), wallpaper Koppie `contents/Images_dark/5120x2880.png`.
- **Calamares**: offline penuh (unpackfs squashfs lokal), branding Koppie,
  modul removeuser + try_remove membersihkan live-only pasca install.
- **Open source 100%**: tanpa linux-firmware dan ucode (sengaja).
