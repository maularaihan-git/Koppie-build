#!/bin/bash
# Build test - aman dari mount sisa & script kependekan.
cd ~/Projects/Koppie-Arch || exit 1

cleanup() {
    echo "=== cleanup mount sisa ==="
    for m in $(findmnt -R -n -o TARGET "$PWD/work" 2>/dev/null | sort -r); do
        echo "umount: $m"
        sudo umount -lf "$m" 2>/dev/null
    done
    # mksquashfs bisa nyisa jadi orphan kalau mkarchiso dibunuh dari luar
    # (SIGTERM ke `timeout` -> mkarchiso mati, tapi anaknya nggak ikut).
    # Kejadian dua kali: PID 46224, lalu PID 306522 (258% CPU, 5 menit jalan
    # sendiri setelah build-nya exit 143). Dia buang CPU dan nahan disk,
    # jadi build berikutnya jalan di atas I/O yang masih dikerjain mayat ini.
    local mk
    mk=$(pgrep -x mksquashfs 2>/dev/null || true)
    if [ -n "$mk" ]; then
        echo "membunuh mksquashfs orphan (pid $mk)"
        sudo kill -9 $mk 2>/dev/null
    fi
}
trap cleanup EXIT

sudo rm -rf work out

LOG="build-$(date +%Y%m%d-%H%M%S).log"
echo "LOG=$LOG"

# 3000 (50 menit) ngebunuh build yang butuh ~2 jam -> exit 124. Naikkan ke 4 jam:
# tetap ada safety net kalau mkarchiso hang, tapi nggak motong build normal.
timeout 14400 sudo mkarchiso -v . > "$LOG" 2>&1
rc=$?
echo "EXIT=$rc" >> "$LOG"

echo "=== hasil (exit=$rc) ==="
tail -30 "$LOG"
echo "=== out/ ==="
ls -lh out/ 2>/dev/null || echo "(tidak ada out/)"
exit $rc
