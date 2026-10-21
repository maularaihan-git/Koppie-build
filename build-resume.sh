#!/bin/bash
# build-resume.sh — LANJUTKAN build yang terputus (jangan hapus work/!).
# Beda dari build-test.sh:
#   * TIDAK rm -rf work  -> marker _run_once tetap ada, 904 paket nggak diulang
#   * timeout 21600 dtk (6 jam) -> sebelumnya 3000 dtk (50 mnt) kependekan,
#     malah bunuh build pas tahap squashfs (exit=124)
#   * trap auto-unmount biar nggak nyisa mount sisa
#   * lock anti-sleep pakai PID FILE (bukan pgrep -f, gampang false-positive)
set -uo pipefail
cd ~/Projects/Koppie-Arch || exit 1

TIMEOUT_SEC="${1:-21600}"
mkdir -p /tmp/koppie
INHIBIT_PIDFILE="/tmp/koppie/koppie-inhibit.pid"

release_lock() {
    # baca PID dari file -> cuma bunuh lock yang KITA bikin (no false-positive)
    if [ -f "$INHIBIT_PIDFILE" ]; then
        local pid comm
        pid=$(cat "$INHIBIT_PIDFILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            # BUG LAMA: `kill -0` TANPA sudo. Lock dibikin pake `sudo setsid`
            # jadi prosesnya ROOT -> kill -0 balikin EPERM (=gagal) -> cabang
            # ini nggak pernah kesampaian -> `sudo kill` nggak pernah jalan.
            # Padahal `rm -f` pidfile-nya JALAN TANPA SYARAT, jadi pidfile
            # hilang tapi proses lock-nya bocor. Tiap resume bikin lock BARU,
            # lama-lama numpuk. Sekarang dicek pake sudo, plus verifikasi comm
            # biar PID lama yang kepakai proses lain nggak ikut kebunuh.
            if sudo kill -0 "$pid" 2>/dev/null; then
                comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
                if [ "$comm" = "systemd-inhibit" ]; then
                    echo "melepas anti-sleep lock (pid $pid)"
                    sudo kill "$pid" 2>/dev/null
                    sleep 1
                    if sudo kill -0 "$pid" 2>/dev/null; then
                        echo "  masih idup, SIGKILL"
                        sudo kill -9 "$pid" 2>/dev/null
                    fi
                else
                    echo "pid $pid bukan systemd-inhibit (comm='$comm') — PID lama, dilepas tanpa dibunuh"
                fi
            fi
        fi
        rm -f "$INHIBIT_PIDFILE"
    fi
}

cleanup() {
    echo "=== cleanup ==="
    for m in $(findmnt -R -n -o TARGET "$PWD/work" 2>/dev/null | sort -r); do
        echo "umount: $m"
        sudo umount -lf "$m" 2>/dev/null
    done
    release_lock
    # kalau timeout kejadian lagi, mksquashfs bisa nyisa jadi orphan
    # (kejadian tadi: PID 46224 tetap jalan setelah mkarchiso mati)
    local mk
    mk=$(pgrep -x mksquashfs 2>/dev/null || true)
    if [ -n "$mk" ]; then
        echo "membunuh mksquashfs sisa (pid $mk)"
        sudo kill -9 $mk 2>/dev/null
    fi
}
trap cleanup EXIT

# ---- anti-sleep lock: pakai PID file supaya deterministik ----
lock_ok=""
if [ -f "$INHIBIT_PIDFILE" ]; then
    old=$(cat "$INHIBIT_PIDFILE" 2>/dev/null)
    # BUG LAMA sama: kill -0 tanpa sudo -> EPERM -> dianggap lock MATI
    # padahal masih idup -> bikin lock KEDUA. Fix: sudo + cek comm-nya beneran.
    if [ -n "$old" ] && sudo kill -0 "$old" 2>/dev/null; then
        [ "$(ps -o comm= -p "$old" 2>/dev/null | tr -d ' ')" = "systemd-inhibit" ] && lock_ok=1
    fi
fi

if [ -z "$lock_ok" ]; then
    rm -f "$INHIBIT_PIDFILE"
    sudo setsid systemd-inhibit \
        --what=sleep:idle:shutdown:handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch \
        --who="Koppie ISO Build" \
        --why="mkarchiso jangan sampai ketiduran" \
        --mode=block \
        sleep infinity </dev/null >/dev/null 2>&1 &
    sleep 1
    # ambil PID systemd-inhibit-nya (bukan shell/sudo pembungkusnya)
    newpid=$(pgrep -x systemd-inhibit -n 2>/dev/null || true)
    if [ -n "$newpid" ]; then
        echo "$newpid" > "$INHIBIT_PIDFILE"
        echo "lock anti-sleep dibuat (pid $newpid)"
    else
        echo "PERINGATAN: gagal bikin lock anti-sleep"
    fi
else
    echo "lock anti-sleep sudah aktif (pid $(cat "$INHIBIT_PIDFILE"))"
fi

# ---- sanity sebelum resume ----
if [ ! -d work ]; then
    echo "work/ tidak ada — jalankan build-test.sh (fresh build)"; exit 3
fi

echo "=== marker SUDAH ada (DILEWATI) ==="
ls work/base.* 2>/dev/null | sed 's|.*/base.|  |'
echo "=== marker BELUM (DIJALANKAN) ==="
for s in _prepare_airootfs_image _mkairootfs_squashfs _mkchecksum _build_iso_image _export_iso_artifacts; do
    [ -e "work/base.$s" ] || echo "  $s"
done

LOG="build-resume-$(date +%Y%m%d-%H%M%S).log"
echo "LOG=$LOG | timeout=${TIMEOUT_SEC}s"

timeout "$TIMEOUT_SEC" sudo mkarchiso -v . > "$LOG" 2>&1
rc=$?
echo "EXIT=$rc" >> "$LOG"

echo "=== hasil (exit=$rc) ==="
if [ "$rc" -eq 124 ]; then
    echo ">>> TIMEOUT ${TIMEOUT_SEC}s. JALANIN LAGI SCRIPT INI — resume otomatis, nggak ngulang paket."
fi
tail -40 "$LOG"
echo "=== out/ ==="
ls -lh out/ 2>/dev/null || echo "(tidak ada out/)"
exit $rc
