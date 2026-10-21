#!/bin/bash
# Build test - aman dari mount sisa & script kependekan.
# FULL CLEAN: hapus work/ + out/ lalu build dari nol (±2 jam).
# Anti-sleep pakai pidfile — pola sama dengan build-resume.sh (lihat sana
# buat penjelasan bug lama: `kill -0` tanpa sudo -> EPERM -> lock bocor).
cd ~/Projects/Koppie-Arch || exit 1

mkdir -p /tmp/koppie
INHIBIT_PIDFILE="/tmp/koppie/koppie-inhibit.pid"

release_lock() {
    # cuma bunuh lock yang KITA bikin (baca PID dari file + verifikasi comm)
    if [ -f "$INHIBIT_PIDFILE" ]; then
        local pid comm
        pid=$(cat "$INHIBIT_PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && sudo kill -0 "$pid" 2>/dev/null; then
            comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
            if [ "$comm" = "systemd-inhibit" ]; then
                echo "melepas anti-sleep lock (pid $pid)"
                sudo kill "$pid" 2>/dev/null
                sleep 1
                sudo kill -0 "$pid" 2>/dev/null && sudo kill -9 "$pid" 2>/dev/null
            else
                echo "pid $pid bukan systemd-inhibit (comm='$comm') — dilepas tanpa dibunuh"
            fi
        fi
        rm -f "$INHIBIT_PIDFILE"
    fi
}

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
    release_lock
}
trap cleanup EXIT

# ---- anti-sleep lock (pidfile, deterministik) ----
lock_ok=""
if [ -f "$INHIBIT_PIDFILE" ]; then
    old=$(cat "$INHIBIT_PIDFILE" 2>/dev/null)
    # kill -0 HARUS pake sudo: lock dibikin root, tanpa sudo balikin EPERM
    # (=dianggap mati) -> bikin lock KEDUA -> numpuk.
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

echo "=== FULL CLEAN: hapus work/ + out/ ==="
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
