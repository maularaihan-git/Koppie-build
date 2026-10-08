#!/bin/bash
# Koppie Linux - build ISO anti-tidur.
# Pakai: ./build.sh  (jalanin dari ~/Projects/Koppie-Arch/)
# Selama mkarchiso jalan: sleep/idle/lid-switch/shutdown di-BLOKIR.
# Habis selesai (sukses/gagal): blokir OTOMATIS lepas sendiri.
set -e
cd "$(dirname "$0")"

echo "=== [1/3] cek sudo ==="
sudo -n true || { echo "ERROR: sudo minta password, grant dulu"; exit 1; }

echo "=== [2/3] build ISO (sleep DISABLE selama build) ==="
LOG="build-$(date +%Y%m%d-%H%M%S).log"
echo "log lengkap: $LOG"
sudo systemd-inhibit \
    --what=shutdown:sleep:idle:handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch \
    --who="Koppie ISO Build" \
    --why="mkarchiso jangan sampai ketiduran" \
    --mode=block \
    mkarchiso -v . 2>&1 | tee "$LOG"

echo "=== [3/3] SELESAI - inhibit lepas otomatis ==="
ls -lh out/ 2>/dev/null | grep -E "iso|sha" || echo "(cek folder out/)"
