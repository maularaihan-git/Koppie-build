# Koppie — Catatan Fix Calamares (15–16 Okt 2026)

## ISO hasil build
- File: `out/koppie-2026.10.15-x86_64.iso` (1.8 GB)
- SHA256: `57e2178cfc4b9a5628862853ee17875688871ffe9ed19cc18b4c763dff704b5e`
- Cara cek USB hasil burn: `head -c <ukuran-iso> /dev/sdX | sha256sum` harus sama dengan di atas.
- Cara burn: `sudo dd if=<file.iso> of=/dev/sdX bs=4M status=progress conv=fsync oflag=direct && sync`

## 2 error Calamares yang diperbaiki
1. `mkinitcpio -P` gagal: `'/boot/vmlinuz-linux-lts' must be readable`
   Penyebab: `contextualprocess` bikin `ln -sf` ke `/run/archiso/copytoram/...`,
   lalu unpackfs `rsync -a` menyalin symlink mentah-mentah → di target jadi
   symlink gantung → mkinitcpio nolak.
   Fix: `cp -Lf` (file asli) + guard di shellprocess sebelum `mkinitcpio -P`
   (ambil kernel dari `/lib/modules/*/vmlinuz` kalau `/boot/vmlinuz` kosong).
2. `error: failed to prepare transaction (could not satisfy dependencies)`
   Penyebab: `packages.conf` mau hapus `mkinitcpio-archiso`, tapi paket
   `koppie-archiso-hookfix` depends ke paket itu.
   Fix: `koppie-archiso-hookfix` masuk daftar `try_remove` di `packages.conf`.

## Commit terkait
- `koppie-repo` → `0e88176` (fix calamares-config-koppie 1.0.0-2 + repo-add)
- `Koppie-build` → `3fe7cb5` (.gitignore)

## Kalau install gagal — JALANKAN INI SEKALI-PASTE di live ISO, kirim outputnya
```bash
sudo sh -c '{ echo "=== CMDLINE:"; cat /proc/cmdline; echo "=== VERSI:"; pacman -Q calamares calamares-config-koppie koppie-archiso-hookfix; echo "=== COPYTORAM:"; ls -la /run/archiso/copytoram/; echo "=== BOOTMNT:"; ls -la /run/archiso/bootmnt/koppie/x86_64/ /run/archiso/bootmnt/koppie/boot/x86_64/; echo "=== TARGET-BOOT:"; ls -la /tmp/calamares-root-*/boot/; echo "=== DISK:"; df -h / /tmp; } 2>&1 | tee /tmp/diag.txt'; sudo grep -n -B2 -A15 -iE "must be readable|could not satisfy|exit code: 1" /root/.cache/calamares/session.log | tail -50 | tee -a /tmp/diag.txt; echo "--- kirim isi /tmp/diag.txt ---"
```
Cek cepat: `pacman -Q calamares-config-koppie` harus `1.0.0-2` (kalau `1.0.0-1`
berarti ke-boot ISO lama).
