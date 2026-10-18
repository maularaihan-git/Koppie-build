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

# 6. AKTIFKAN os-prober di /etc/default/grub (fix dualboot).
#    GRUB 2.16 MENGE-HARDCODE GRUB_DISABLE_OS_PROBER="true" di dalam
#    /usr/sbin/grub-mkconfig, jadi os-prober gak PERNAH jalan walau
#    paketnya kepasang. Satu-satunya cara ngalahin: uncomment baris
#    GRUB_DISABLE_OS_PROBER=false di /etc/default/grub target.
#    Kenapa di sini (chroot customize_airootfs) dan bukan di airootfs/?
#    karena /etc/default/grub dimiliki paket 'grub' — taruh langsung di
#    airootfs/ kena error "exists in filesystem" pas pacstrap.
#    Modul grubcfg Calamares CUMA nulis GRUB_DISTRIBUTOR, dia gak nyentuh
#    baris ini, jadi harus dibake di sini biar tiap install auto ke-detek.
GRUB_DEFAULT_FILE=/etc/default/grub
if [ -f "$GRUB_DEFAULT_FILE" ]; then
    if grep -q '^#GRUB_DISABLE_OS_PROBER=false' "$GRUB_DEFAULT_FILE"; then
        sed -i 's|^#GRUB_DISABLE_OS_PROBER=false|GRUB_DISABLE_OS_PROBER=false|' "$GRUB_DEFAULT_FILE"
    elif ! grep -q '^GRUB_DISABLE_OS_PROBER=false' "$GRUB_DEFAULT_FILE"; then
        echo 'GRUB_DISABLE_OS_PROBER=false' >> "$GRUB_DEFAULT_FILE"
    fi
fi

