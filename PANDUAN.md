# Koppie Linux

Custom Arch Linux live ISO dengan KDE Plasma 6, SDDM, dan installer
Calamares offline. 100% open source, kernel linux-lts, target ukuran
ISO di bawah 2 GiB (XZ).

## Isi Repository

Repository ini berisi folder project archiso siap build:

- `airootfs/` — overlay sistem live (lihat PANDUAN-BUILD.md §1)
- `grub/`, `syslinux/`, `efiboot/` — konfigurasi bootloader
- `packages.x86_64` — daftar 120+ paket
- `pacman.conf`, `profiledef.sh`, `bootstrap_packages` — konfigurasi build
- `build.sh` — script build
- `PANDUAN-BUILD.md` — cara download & build
- `PANDUAN.md` — panduan umum dan arsitektur

## Cara Download Folder Ini

### Opsi A — Clone via git (disarankan)

```bash
sudo pacman -S --needed git
git clone https://github.com/maularaihan-git/Koppie-build.git ~/Projects/Koppie-build
```

### Opsi B — Download ZIP

1. Buka halaman repository di GitHub
2. Klik tombol hijau **Code** → **Download ZIP**
3. Ekstrak ke `~/Projects/` sehingga menjadi `~/Projects/Koppie-build/`

> CATATAN: setiap distro/proyek BARU wajib ditaruh di dalam `~/Projects/`
> (contoh: `~/Projects/Koppie-Arch`), jangan di `~` atau `/tmp`.

## Langkah Berikutnya

Baca `PANDUAN-BUILD.md` untuk menyiapkan local repo, build ISO,
menulis ke USB (dengan verifikasi sha256), dan menguji di hardware.

## Spesifikasi Singkat

| Komponen | Pilihan |
|---|---|
| Kernel | linux-lts (+ headers untuk DKMS/KDM) |
| Desktop | KDE Plasma 6 (plasma-desktop + manual, Wayland) |
| Display manager | SDDM (breeze, autologin live) |
| Installer | Calamares 3.4 offline (GRUB BIOS+UEFI) |
| Ikon / GTK / Kursor | Papirus-Dark / Orchis-dark / Bibata-Modern-Classic 28 |
| Office | LibreOffice Still + bahasa Indonesia |
| Lisensi | 100% open source (tanpa firmware/ucode proprietary) |
