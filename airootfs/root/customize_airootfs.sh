#!/bin/bash
# Koppie Linux - jalan OTOMATIS di akhir mkarchiso (dalam chroot target).
# Tugas: timpa file paket dengan versi custom Koppie
# (tidak bisa taruh langsung di airootfs karena konflik "exists in filesystem" pas pacstrap).
set -e
OV=/usr/share/koppie/overrides

# 1. Theme spinner custom (watermark Koppie + animasi host)
cp -rf "${OV}/plymouth-spinner/." /usr/share/plymouth/themes/spinner/

# 2. plymouthd.conf (Theme=spinner)
cp -f "${OV}/plymouthd.conf" /etc/plymouth/plymouthd.conf

# 3. Daftarkan theme ke initramfs (biar splash muncul sejak awal boot)
if command -v plymouth-set-default-theme >/dev/null; then
    plymouth-set-default-theme spinner
fi

# 4. Pangkas lemak NOL fungsi (doc/man/locale asing) - hemat ~880MB installed / ~300MB ISO
#    en* + id* + C.UTF-8 dipertahankan, sisanya buang. Fallback otomatis ke Inggris.
rm -rf /usr/share/doc /usr/share/man
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
    ! -name 'en*' ! -name 'id*' ! -name 'locale.alias' -exec rm -rf {} +
for d in /usr/share/help/*; do
    case "$d" in */en*|*/id*) ;; *) rm -rf "$d";; esac
done

# 5. TIMPA waterfall bawaan breeze dengan wallpaper Koppie (milik paket breeze,
#    jadi HARUS di sini, bukan di airootfs langsung - kalau di airootfs = build
#    GAGAL "exists in filesystem" kayak kasus plymouth dulu).
#    Hasil: entry Next tetap ada di picker tapi gambarnya Koppie (persis kayak
#    yang lo lakuin di host: timpa, bukan bikin baru).
KP=/usr/share/wallpapers/Koppie/contents/Images_dark/5120x2880.png
for f in /usr/share/wallpapers/Next/contents/images/*.png /usr/share/wallpapers/Next/contents/images_dark/*.png; do
    [ -f "$f" ] && cp -f "$KP" "$f"
done
sed -i 's|^background=.*|background=/usr/share/wallpapers/Koppie/contents/Images_dark/5120x2880.png|' \
    /usr/share/sddm/themes/breeze/theme.conf

