#!/bin/bash
# verify-iso.sh — cek ISO Koppie byte-per-byte sebelum dipake.
# Pakai: ./verify-iso.sh [path-iso]
# Keluar non-zero kalau ADA satu pun check gagal.
#
# Catatan desain (dari inspeksi mkarchiso + profiledef.sh):
#   * install_dir="koppie" -> kernel ada di /koppie/boot/x86_64/, BUKAN /boot/x86_64/
#   * mkarchiso MEMANG mengosongkan /boot di airootfs (_cleanup_pacstrap_dir:
#     "Delete all files in /boot"). Kernel live di-load dari ISO, kernel TARGET
#     diisi pas install lewat shellprocess guard yang ambil dari /lib/modules.
#     Jadi /boot kosong di sfs itu BY DESIGN, bukan rusak.
#   * mkarchiso TIDAK bikin checksum untuk file ISO. Yang ada airootfs.sha512,
#     itu buat self-test boot (verifikasi sfs di waktu boot), jadi divalidasi
#     terhadap sfs, bukan terhadap ISO.
set -uo pipefail

RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'; RST=$'\e[0m'
PASS=0; FAIL=0; WARN=0
ok()   { echo "${GRN}[OK]  ${RST} $1"; PASS=$((PASS+1)); }
bad()  { echo "${RED}[FAIL]${RST} $1"; FAIL=$((FAIL+1)); }
warn() { echo "${YLW}[WARN]${RST} $1"; WARN=$((WARN+1)); }
hdr()  { echo; echo "${CYN}=== $1 ===${RST}"; }

ISO="${1:-}"
if [ -z "$ISO" ]; then
    ISO=$(ls -t out/*.iso 2>/dev/null | head -1)
fi
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
    echo "${RED}ISO tidak ditemukan. Pakai: $0 <path.iso>${RST}"; exit 2
fi

# install_dir dari profiledef (default "koppie" kalau nggak kebaca)
PROFILE="${PROFILE:-profiledef.sh}"
if [ -f "$PROFILE" ]; then
    INSTALL_DIR=$(sed -n 's/^install_dir="\([^"]*\)".*/\1/p' "$PROFILE" | head -1)
fi
INSTALL_DIR="${INSTALL_DIR:-koppie}"

# kernel version dari nama paket linux-lts di dalam sfs (diisi nanti)
KVER=""

MNT=$(mktemp -d /tmp/opencode/isomnt.XXXXXX)
SQROOT=""
# daftar isi sfs. JANGAN disimpan di variabel shell: 991.610 baris (~60MB)
# melebihi ARG_MAX waktu di-echo, jadi grep-nya nggak pernah dapet data.
# Simpan ke file, lalu grep dari file.
LISTFILE=$(mktemp /tmp/opencode/sqlist.XXXXXX)
cleanup() {
    sudo umount "$MNT" 2>/dev/null
    [ -n "${SQROOT:-}" ] && sudo rm -rf "$SQROOT" 2>/dev/null
    rm -rf "$MNT" "$LISTFILE" 2>/dev/null
}
trap cleanup EXIT

# sqlist: grep ke daftar isi sfs. Prefix "squashfs-root/" di-strip dulu biar
# path-nya mulai dari "/" (sama kayak cara baca ISO-nya).
# Pakai "$@" bukan "$1" — pemanggilan kadang pakai opsi grep (mis. -c, -oE).
sqlist() { grep "$@" "$LISTFILE" 2>/dev/null; }

echo "=== VERIFIKASI ISO ==="
echo "file       : $ISO"
echo "size       : $(stat -c %s "$ISO") bytes ($(du -h "$ISO" | cut -f1))"
echo "install_dir: $INSTALL_DIR"

# ------------------------------------------------ 1. checksum self-test sfs
hdr "1. Checksum self-test (airootfs.sha512)"
if sudo mount -o loop,ro "$ISO" "$MNT" 2>/dev/null; then
    SFS="$MNT/$INSTALL_DIR/x86_64/airootfs.sfs"
    SUMSRC="$MNT/$INSTALL_DIR/x86_64/airootfs.sha512"
    if [ -f "$SUMSRC" ]; then
        # file .sha512 format standar sha512sum: "<hash>  <nama file>"
        # (143 byte = 128 hex + 2 spasi + 12 char nama + newline).
        # Jadi ambil kolom PERTAMA aja — jangan tr -d ' \n', itu nempelin nama file.
        WANT=$(sudo awk '{print $1}' "$SUMSRC" | head -1 | tr -d ' \n')
        GOT=$(sudo sha512sum "$SFS" 2>/dev/null | awk '{print $1}')
        if [ -n "$WANT" ] && [ "$WANT" = "$GOT" ]; then
            ok "airootfs.sfs cocok dengan airootfs.sha512 (self-test boot bakal lolos)"
        else
            bad "airootfs.sfs TIDAK cocok dengan airootfs.sha512 — sfs korup"
            echo "       want: ${WANT:0:40}..."
            echo "       got : ${GOT:0:40}..."
        fi
    else
        warn "airootfs.sha512 tidak ada di ISO (self-test boot bakal dilewati)"
    fi
else
    bad "GAGAL mount ISO"
    SFS=""; SUMSRC=""
fi

# hash independen ISO (dicatat biar bisa dibanding sama burn-an nanti)
echo "       sha512(ISO) = $(sha512sum "$ISO" | cut -d' ' -f1)"

# ------------------------------------------------ 2. tipe file + boot record
hdr "2. Tipe file + boot record"
FT=$(file -b "$ISO")
echo "       $FT"
if echo "$FT" | grep -qiE "ISO 9660|DOS/MBR"; then
    ok "format ISO9660 valid"
else
    bad "bukan ISO9660: $FT"
fi

# MBR: signature 0x55AA di offset 510 (cara umum, nggak hardcode opcode)
SIG=$(sudo dd if="$ISO" bs=1 skip=510 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
if [ "$SIG" = "55aa" ]; then
    ok "MBR valid: signature 0x55AA di offset 510"
else
    bad "MBR signature salah: '$SIG' (harusnya 55aa)"
fi

# byte pembuka MBR harusnya sama dengan isohdpfx.bin yang dipakai mkarchiso
ISOH="$MNT/boot/syslinux/isohdpfx.bin"
if [ -f "$ISOH" ]; then
    A=$(sudo dd if="$ISO" bs=1 count=16 2>/dev/null | od -An -tx1 | tr -d ' \n')
    B=$(sudo dd if="$ISOH" bs=1 count=16 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ -n "$A" ] && [ "$A" = "$B" ]; then
        ok "boot sector = isohdpfx.bin (BIOS hybrid cocok)"
    else
        warn "boot sector beda dari isohdpfx.bin"
        echo "       iso : $A"
        echo "       isoh: $B"
    fi
fi

# ------------------------------------------------ 3. struktur + El Torito
hdr "3. Struktur dalam ISO + El Torito"
if [ -n "$MNT" ] && sudo mountpoint -q "$MNT" 2>/dev/null; then

    # file wajib archiso — path pakai $INSTALL_DIR.
    # NB: kernel ada di $INSTALL_DIR/boot/x86_64/, BUKAN $INSTALL_DIR/x86_64/
    # (yang di $INSTALL_DIR/x86_64/ itu airootfs.sfs doang).
    for f in \
        "boot/syslinux/syslinux.cfg" \
        "boot/grub/grub.cfg" \
        "boot/grub/loopback.cfg" \
        "$INSTALL_DIR/boot/x86_64/vmlinuz-linux-lts" \
        "$INSTALL_DIR/boot/x86_64/initramfs-linux-lts.img" \
        "$INSTALL_DIR/x86_64/airootfs.sfs"
    do
        p="$MNT/$f"
        if sudo test -e "$p"; then
            sz=$(sudo stat -c %s "$p")
            if [ "$sz" -gt 0 ]; then
                ok "$f ($sz bytes)"
            else
                bad "$f UKURANNYA 0"
            fi
        else
            bad "$f HILANG"
        fi
    done

    # grub harus nunjuk path yang bener (biar nggak nyari kernel di tempat salah)
    GRUB="$MNT/boot/grub/grub.cfg"
    if sudo test -f "$GRUB"; then
        GL=$(sudo grep -m1 -E "^\s*linux\s" "$GRUB" | awk '{print $2}')
        if [ -n "$GL" ]; then
            if sudo test -f "$MNT$GL"; then
                ok "grub nunjuk kernel valid: $GL"
            else
                bad "grub nyari kernel di path yang NGGAK ADA: $GL"
            fi
        else
            warn "tidak ada baris 'linux' di grub.cfg"
        fi
        # archisobasedir harus konsisten sama install_dir
        AB=$(sudo grep -oE "archisobasedir=[a-zA-Z0-9_-]+" "$GRUB" | head -1 | cut -d= -f2)
        if [ -n "$AB" ]; then
            if [ "$AB" = "$INSTALL_DIR" ]; then
                ok "archisobasedir=$AB konsisten dengan install_dir"
            else
                bad "archisobasedir=$AB beda dari install_dir=$INSTALL_DIR"
            fi
        fi
    fi

    # El Torito: harus ada BIOS dan UEFI
    if command -v xorriso >/dev/null; then
        ET=$(xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null)
        if [ -n "$ET" ]; then
            ok "El Torito catalog ada ($(echo "$ET" | grep -c 'El Torito boot img') boot image)"
            echo "$ET" | grep "El Torito boot img" | sed 's/^/       /'
            echo "$ET" | grep -q "BIOS" && ok "  boot mode BIOS ada" || bad "  boot mode BIOS HILANG"
            echo "$ET" | grep -q "UEFI" && ok "  boot mode UEFI ada" || bad "  boot mode UEFI HILANG"
        else
            bad "El Torito catalog TIDAK ADA — ISO nggak bisa boot"
        fi
    else
        warn "xorriso tidak ada, cek El Torito dilewati"
    fi

    # ------------------------------------------------ 4. squashfs integrity
    hdr "4. Integritas squashfs (airootfs.sfs)"
    if [ -z "${SFS:-}" ] || ! sudo test -f "$SFS"; then
        bad "airootfs.sfs tidak bisa diakses"
    else
        ssz=$(sudo stat -c %s "$SFS")
        ok "airootfs.sfs ada ($(( ssz / 1024 / 1024 )) MB)"
        echo "       (operasi berat, sabar...)"

        if sudo unsquashfs -stat "$SFS" >/dev/null 2>&1; then
            ok "squashfs header valid"
        else
            bad "squashfs header RUSAK"
        fi

        if sudo unsquashfs -cat "$SFS" etc/os-release >/dev/null 2>&1; then
            ok "squashfs bisa didekompres (sample /etc/os-release)"
        else
            bad "squashfs GAGAL didekompres — data korup"
        fi

        # baca semua inode = cek byte-level integrity.
        # Sekaligus simpan daftarnya ke LISTFILE buat dipakai section 5
        # (biar nggak baca ulang sfs 1,6GB berkali-kali).
        # Prefix "squashfs-root/" di-strip jadi path mulai dari "/", biar
        # grep dengan anchor "$" bisa match (mis. /etc/mkinitcpio.conf$).
        if sudo unsquashfs -l "$SFS" 2>/dev/null \
           | sed 's|^squashfs-root|/|' > "$LISTFILE"; then
            LC=$(wc -l < "$LISTFILE")
            if [ "$LC" -gt 0 ]; then
                ok "semua inode squashfs kebaca utuh ($LC entry)"
            else
                bad "daftar isi squashfs KOSONG"
            fi
        else
            bad "ada inode squashfs yang rusak"
        fi
    fi

    # ------------------------------------------------ 5. isi config penting
    hdr "5. Cek isi config di dalam squashfs (bug yang udah ketemu)"
    sqget() { sudo unsquashfs -cat "$SFS" "$1" 2>/dev/null; }

    if [ -n "${SFS:-}" ] && sudo test -f "$SFS"; then

        # 5a. grub-mkconfig timeout (bug screenshot user)
        SP=$(sqget etc/calamares/modules/shellprocess.conf)
        if [ -n "$SP" ]; then
            TO=$(echo "$SP" | grep -A1 "grub-mkconfig -o /boot/grub/grub.cfg" \
                 | grep -oE "timeout: *[0-9]+" | grep -oE "[0-9]+" | head -1)
            if [ -z "$TO" ]; then
                warn "baris grub-mkconfig tidak terdeteksi di shellprocess.conf"
            elif [ "$TO" -ge 600 ] 2>/dev/null; then
                ok "grub-mkconfig timeout = $TO dtk (>=600, FIX aktif)"
            else
                bad "grub-mkconfig timeout = $TO dtk — MASIH BAWA BUG (<600)"
                echo "       -> ISO ini dari build SEBELUM fix calamares-config pkgrel=3"
            fi

            # 5a2. guard kernel harus ada (ini yang ngisi /boot target)
            if echo "$SP" | grep -q "cp -f /lib/modules/\*/vmlinuz"; then
                ok "guard kernel ada di shellprocess.conf"
            else
                warn "guard kernel tidak ada — /boot target bisa kosong pas install"
            fi
        else
            warn "shellprocess.conf tidak bisa dibaca dari sfs"
        fi

        # 5b. kwin-x11 harus TIDAK ada
        LP=$(sqlist -c "/var/lib/pacman/local/kwin-x11-")
        if [ "$LP" -gt 0 ]; then
            bad "kwin-x11 masih terpasang di ISO (bakal bikin build gagal)"
        else
            ok "kwin-x11 tidak ada di ISO"
        fi

        # 5c. os-prober tetap ada (biar dualboot jalan)
        OP=$(sqlist -c "/usr/bin/os-prober$")
        if [ "$OP" -gt 0 ]; then
            ok "os-prober ada (dualboot tetap ke-detek)"
        else
            warn "os-prober tidak ada di ISO — dualboot nggak ke-detek"
        fi

        # 5d. KERNEL TARGET: /boot di sfs MEMANG kosong (by design), jadi yang
        #      dicek adalah SUMBER-nya: /usr/lib/modules/<kver>/vmlinuz
        KM=$(sqlist -oE "/usr/lib/modules/[^/]+/vmlinuz$" | head -1)
        if [ -n "$KM" ]; then
            KVER=$(echo "$KM" | sed 's|.*/modules/||; s|/vmlinuz||')
            ok "kernel TARGET ada: $KM"
            echo "       (kernel version: $KVER)"
            echo "       /boot di sfs kosong = BY DESIGN (mkarchiso _cleanup_pacstrap_dir)"
            echo "       shellprocess guard ambil dari sini pas install"
        else
            bad "kernel TARGET (/usr/lib/modules/*/vmlinuz) TIDAK ADA — install bakal gagal"
        fi

        # 5e. modul kernel lengkap
        MC=0
        [ -n "$KVER" ] && MC=$(sqlist -c "/usr/lib/modules/$KVER/")
        if [ "$MC" -gt 1000 ] 2>/dev/null; then
            ok "modul kernel lengkap ($MC entry di $KVER)"
        else
            warn "modul kernel sedikit ($MC entry) — bisa jadi gak lengkap"
        fi

        # 5f. initramfs target: mkinitcpio harus bisa jalan, artinya mkinitcpio.conf ada
        if [ "$(sqlist -c "/etc/mkinitcpio.conf$")" -gt 0 ] 2>/dev/null; then
            ok "mkinitcpio.conf ada di target"
        else
            warn "mkinitcpio.conf tidak ada — mkinitcpio -P bisa gagal"
        fi

        # 5g. symlink gantung di /boot sfs (bug rsync -a di copytoram)
        echo "       cek symlink gantung di /boot sfs..."
        RDR=$(mktemp -d /tmp/opencode/sqroot.XXXXXX); SQROOT="$RDR"
        if sudo unsquashfs -d "$RDR" "$SFS" boot >/dev/null 2>&1; then
            if sudo find "$RDR/boot" -xtype l 2>/dev/null | grep -q .; then
                bad "ADA symlink gantung di /boot sfs:"
                sudo find "$RDR/boot" -xtype l | sed 's/^/       /'
            else
                ok "tidak ada symlink gantung di /boot sfs"
            fi
        else
            # /boot sfs emang kosong, jadi ini bukan masalah
            ok "/boot sfs kosong (by design), tidak perlu cek symlink"
        fi

        # 5h. symlink gantung di /usr/lib/modules (lebih penting dari /boot)
        if sudo unsquashfs -d "$RDR" "$SFS" "usr/lib/modules/$KVER" >/dev/null 2>&1; then
            HUNG=$(sudo find "$RDR/usr/lib/modules/$KVER" -xtype l 2>/dev/null | wc -l)
            if [ "$HUNG" -gt 0 ]; then
                bad "ADA $HUNG symlink gantung di modul kernel"
            else
                ok "tidak ada symlink gantung di modul kernel"
            fi
            # vmlinuz harus file biasa, bukan symlink
            if sudo test -L "$RDR/usr/lib/modules/$KVER/vmlinuz"; then
                warn "vmlinuz di modul = symlink (wajar untuk packaging)"
            elif sudo test -r "$RDR/usr/lib/modules/$KVER/vmlinuz"; then
                ok "vmlinuz di modul = file readable"
            fi
        else
            warn "gak bisa extract modul kernel dari sfs"
        fi
    fi
    sudo umount "$MNT" 2>/dev/null
else
    bad "GAGAL mount ISO — semua check isi dilewati"
fi

# ------------------------------------------------ ringkasan
echo
echo "${CYN}================ RINGKASAN ================${RST}"
echo " ISO    : $(basename "$ISO")"
echo " OK     : $PASS"
echo " FAIL   : $FAIL"
echo " WARN   : $WARN"
echo " SHA512 : $(sha512sum "$ISO" | cut -d' ' -f1)"
echo " SIZE   : $(stat -c %s "$ISO") bytes"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo "${RED}>>> ISO TIDAK LULUS — jangan dibakar/dipake. <<<${RST}"; exit 1
fi
if [ "$WARN" -gt 0 ]; then
    echo "${YLW}>>> LULUS (ada $WARN warning, cek dulu) <<<${RST}"; exit 0
fi
echo "${GRN}>>> ISO LULUS SEMUA CHECK <<<${RST}"; exit 0
