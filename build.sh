#!/bin/bash
# Koppie Linux - build ISO anti-tidur.
# Pakai: ./build.sh  (jalanin dari ~/Projects/Koppie-Arch/)
# Selama mkarchiso jalan: sleep/idle/lid-switch/shutdown di-BLOKIR.
# Habis selesai (sukses/gagal): blokir OTOMATIS lepas sendiri.
set -e
set -o pipefail   # WAJIB: tanpa ini exit code pipeline = exit code `tee` (selalu 0),
                  # jadi mkarchiso GAGAL pun script tetap bilang "SELESAI" (success palsu).
cd "$(dirname "$0")"

echo "=== [1/3] cek sudo ==="
sudo -n true || { echo "ERROR: sudo minta password, grant dulu"; exit 1; }

echo "=== [2/3] build ISO (sleep DISABLE selama build) ==="
LOG="build-$(date +%Y%m%d-%H%M%S).log"
echo "log lengkap: $LOG"
rc=0
sudo systemd-inhibit \
    --what=shutdown:sleep:idle:handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch \
    --who="Koppie ISO Build" \
    --why="mkarchiso jangan sampai ketiduran" \
    --mode=block \
    mkarchiso -v . 2>&1 | tee "$LOG" || rc=$?

# `set -o pipefail` bikin pipeline ini non-zero kalau MKARCHISO gagal (bukan `tee`),
# jadi `|| rc=$?` nangkep kegagalan asli. JANGAN pakai PIPESTATUS di sini —
# `|| rc=$?` sendiri nge-reset PIPESTATUS jadi 0, dan itu nimpa rc yang bener.
if [ "$rc" -ne 0 ]; then
    echo "=== [X] BUILD GAGAL (mkarchiso exit=$rc) — jangan bakar ISO-nya! ==="
    echo "     cek log: $LOG"
    exit "$rc"
fi

echo "=== [3/3] SELESAI - inhibit lepas otomatis ==="
ls -lh out/ 2>/dev/null | grep -E "iso|sha" || echo "(cek folder out/)"
