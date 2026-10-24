#!/bin/bash
# Koppie Linux - build ISO anti-tidur.
# Pakai: ./build.sh  (jalanin dari ~/Projects/Koppie-Arch/)
# Selama mkarchiso jalan: sleep/idle/lid-switch/shutdown di-BLOKIR.
# Habis selesai (sukses/gagal): blokir OTOMATIS lepas sendiri.
#
# WORKFLOW (1 clone, langsung build):
#   git clone --recurse-submodules https://github.com/maularaihan-git/Koppie-build.git ~/Projects/Koppie-Arch
#   cd ~/Projects/Koppie-Arch && ./build.sh
#
# koppie-repo (pkg custom + koppie.db) ada sebagai git submodule di koppie-repo/
# build.sh auto-update submodule sebelum build — tidak perlu clone terpisah.
set -e
set -o pipefail   # WAJIB: tanpa ini exit code pipeline = exit code `tee` (selalu 0),
                  # jadi mkarchiso GAGAL pun script tetap bilang "SELESAI" (success palsu).
cd "$(dirname "$0")"

echo "=== [1/4] cek sudo ==="
sudo -n true || { echo "ERROR: sudo minta password, grant dulu"; exit 1; }

echo "=== [2/4] sync koppie-repo submodule ==="
# Auto-init + update submodule koppie-repo (packages + koppie.db).
# Kalau belum pernah clone --recurse-submodules, langkah ini yang fetch-nya.
if [ -f .gitmodules ]; then
    git submodule update --init --remote koppie-repo
    echo "koppie-repo: $(git -C koppie-repo describe --tags 2>/dev/null || git -C koppie-repo rev-parse --short HEAD)"
else
    echo "WARNING: .gitmodules tidak ada, pastikan koppie-repo/ sudah tersedia"
fi

# Otomatis sesuaikan Server repo [koppie] di pacman.conf ke lokasi direktori saat ini
# (Siapapun dan di folder manapun di-clone, build langsung jalan tanpa perlu ubah path manual)
REPO_DIR="$PWD/koppie-repo/x86_64"
if [ -d "$REPO_DIR" ]; then
    sed -i -E "s|^Server = file://.*/koppie-repo/x86_64$|Server = file://${REPO_DIR}|" pacman.conf
    echo "pacman.conf [koppie]: file://${REPO_DIR}"
fi

echo "=== [3/4] build ISO (sleep DISABLE selama build) ==="
LOG="build-$(date +%Y%m%d-%H%M%S).log"
echo "log lengkap: $LOG"
# Bersihkan db.lck kalau ada sisa di work sebelum lanjut
if [ -f work/airootfs/var/lib/pacman/db.lck ]; then
    echo "=== membersihkan sisa db.lck di work/airootfs ==="
    sudo rm -f work/airootfs/var/lib/pacman/db.lck
fi

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

echo "=== [4/4] SELESAI - inhibit lepas otomatis ==="
LATEST_ISO=$(ls -t out/*.iso 2>/dev/null | head -1 || true)
if [ -n "$LATEST_ISO" ] && [ -x ./verify-iso.sh ]; then
    echo "=== menjalankan verify-iso.sh otomatis ==="
    ./verify-iso.sh "$LATEST_ISO" || true
fi
ls -lh out/ 2>/dev/null | grep -E "iso|sha" || echo "(cek folder out/)"
