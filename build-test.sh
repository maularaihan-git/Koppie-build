#!/bin/bash
# Build test - aman dari mount sisa & script kependekan.
cd ~/Projects/Koppie-Arch || exit 1

cleanup() {
    echo "=== cleanup mount sisa ==="
    for m in $(findmnt -R -n -o TARGET "$PWD/work" 2>/dev/null | sort -r); do
        echo "umount: $m"
        sudo umount -lf "$m" 2>/dev/null
    done
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
