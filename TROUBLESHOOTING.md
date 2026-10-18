# Koppie Linux — Panduan Kalau Error Pas Install

Dokumen ini ada di GitHub supaya **bisa diambil dari live environment**:

```bash
curl -fsSL https://raw.githubusercontent.com/maularaihan-git/Koppie-build/main/TROUBLESHOOTING.md
# atau biar bisa dibaca pelan-pelan:
curl -fsSL -o /tmp/ts.md https://raw.githubusercontent.com/maularaihan-git/Koppie-build/main/TROUBLESHOOTING.md
cat /tmp/ts.md
```

---

## 0. DUA HAL INI DULU — sebelum nyentuh apapun

### A. Log-nya di RAM. Reboot = hilang.

ISO ini sengaja set `Storage=volatile` (lihat `airootfs/etc/systemd/journald.conf.d/`):

```
[Journal]
Storage=volatile
```

Artinya `journalctl` nggak ada yang nyimpen ke disk. **Kalau kamu reboot tanpa nyimpan, semua bukti error lenyap.**

Dan Calamares di ISO ini **tidak pakai modul `logger`** (cek `settings.conf` — modul exec-nya: `contextualprocess partition mount unpackfs machineid bootloader fstab locale keyboard localecfg users displaymanager networkcfg hwclock packages grubcfg shellprocess removeuser umount`), jadi **nggak ada `/var/log/calamares/`**. Log-nya ada di journald = RAM.

### B. Cara masuk shell

| jalan | caranya |
|---|---|
| **dari desktop** | buka **Konsole** (Alt+Space, ketik "konsole") |
| **GUI mati / stuck** | `Ctrl+Alt+F2` sampai `F6`, login pakai table di bawah |
| **balik ke GUI** | `Ctrl+Alt+F1` |

Akun live (dibuat runtime oleh `koppie-live-user.service`):

```
user   : live     password: koppie     sudo: NOPASSWD (nggak minta password)
root   : (kosong di ISO, tapi runtime di-set)  password: koppie
```

---

## 1. SATU COMMAND — kumpulin semua bukti

Jalanin **begitu keliatan error**, sebelum reboot apapun:

```bash
mkdir -p /tmp/ken && {
  echo "=== KOPPIE TROUBLE $(date -Is) ==="
  echo "--- uname ---"; uname -a
  echo "--- lsblk ---"; lsblk -f
  echo "--- free ---";  free -h
  echo "--- df ---";    df -h
  echo
  echo "=== journal: level error (3) ==="
  journalctl -b -p 3 --no-pager | tail -300
  echo
  echo "=== journal: keyword penting ==="
  journalctl -b --no-pager | grep -iE "calamares|grub|os-prober|shellprocess|mkinitcpio|unpackfs|fatal|failed|timeout|segfault|abort" | tail -400
  echo
  echo "=== baloo (crash loop gak?) ==="
  journalctl -b --user --no-pager | grep -iE "baloo|extractor|coredump" | tail -60
  echo "  --- proses baloo ---"
  ps -eo pid,etimes,comm,args | grep -i "[b]aloo"
  echo "  --- jumlah core dump ---"
  coredumpctl list 2>/dev/null | tail -20
  echo
  echo "=== calamares ==="
  echo "--- settings.conf ---"; cat /etc/calamares/settings.conf 2>/dev/null
  echo "--- shellprocess.conf ---"; cat /etc/calamares/modules/shellprocess.conf 2>/dev/null
  echo "--- bootloader.conf ---";   cat /etc/calamares/modules/bootloader.conf 2>/dev/null
  echo "--- grubcfg.conf ---";     cat /etc/calamares/modules/grubcfg.conf 2>/dev/null
  echo
  echo "=== grub ==="
  echo "--- /etc/default/grub (nonkomentar) ---"
  grep -vE '^\s*#|^\s*$' /etc/default/grub 2>/dev/null
  echo "--- GRUB_DISABLE_OS_PROBER ---"
  grep -n "GRUB_DISABLE_OS_PROBER" /etc/default/grub 2>/dev/null
  echo
  echo "=== partisi & fstab ==="
  parted -l 2>&1
  echo "--- /etc/fstab (target, kalau udah ke-write) ---"
  cat /etc/fstab 2>/dev/null
  echo
  echo "=== paket kunci ==="
  pacman -Q 2>/dev/null | grep -iE "^(grub|os-prober|calamares|ntfs-3g|linux|plasma-welcome|baloo|kwin)"
  echo
  echo "=== versi ISO ==="
  cat /etc/os-release 2>/dev/null
  echo "--- airootfs.sfs ---"
  ls -l /run/archiso/bootmnt/koppie/x86_64/airootfs.sfs 2>/dev/null
} > /tmp/ken/report.txt 2>&1

wc -lc /tmp/ken/report.txt
echo "--- preview 80 baris pertama ---"
head -80 /tmp/ken/report.txt
```

---

## 2. SIMPAN report.txt SEBELUM reboot

`/tmp` juga RAM. Pilih salah satu:

```bash
lsblk -f          # cari partisi yang bisa ditulis

# A) punya flashdisk kedua
sudo mount /dev/sdXN /mnt && sudo cp /tmp/ken/report.txt /mnt/ && sudo umount /mnt

# B) tulis ke partisi OS lama (kalau dipertahankan)
sudo mount /dev/sdXN /mnt && sudo cp /tmp/ken/report.txt /mnt/ && sudo umount /mnt

# C) nggak ada media? baca aja layarnya
cat /tmp/ken/report.txt
```

Kalau nggak ada yang bisa ditulis: **fotokan layarnya** atau `cat` bagian yang error terus copy ke aku.

---

## 3. Per skenario

### A. Gak bisa boot sama sekali (layar hitus/stuck/BIOS doang)

1. **Coba TTY dulu** — `Ctrl+Alt+F2`, login `live` / `koppie`
2. Kalau TTY juga mati: boot ulang dari USB lagi, masuk live, lalu:

```bash
lsblk -f                                   # kenali partisi target
sudo mount /dev/sdXN /mnt                  # partisi root target (/)
sudo mount /dev/sdXM /mnt/boot             # kalau /boot terpisah
sudo mount /dev/sdXP /mnt/boot/efi         # partisi EFI (kalau UEFI)
ls /mnt/boot/grub/grub.cfg                 # ada? berarti install kelar, cuma boot-nya gagal
ls /mnt/boot/                               # ada vmlinuz-linux-lts?
```

→ lanjut ke **bagian 4 (rescue)**.

**Secure Boot**: kalau pesannya soal "SBAT" / "not trusted" / "security violation", masuk BIOS dan **matiin Secure Boot**. archiso default nggak ditandatangani.

---

### B. Boot masuk, tapi ada error dialog / plasma-welcome gak nongol / baloo crash

```bash
# baloo crash loop? (harusnya: prosesnya idup dan DIAM)
ps -eo pid,etimes,comm,args | grep -i "[b]aloo"
journalctl -b --user --no-pager | grep -iE "baloo|abort|coredump" | tail -40
coredumpctl list 2>/dev/null | tail -10
systemctl --user status kde-baloo

# drop-in fix-nya kepasang gak?
systemctl --user cat kde-baloo | grep -A2 Environment
cat /etc/systemd/user/kde-baloo.service.d/override.conf

# plasma-welcome terpasang gak?
pacman -Q plasma-welcome
ls /usr/bin/plasma-welcome /usr/lib/qt6/plugins/kf6/kded/kded_plasma_welcome.so
```

**Harapannya**: `Environment=QT_QPA_PLATFORM=offscreen` ada, dan `coredumpctl list` kosong.

---

### C. Calamares error / instalasi gagal

**Tips penting**: jalankan Calamares **dari Konsole** supaya output-nya ke-capture (karena nggak ada modul logger):

```bash
sudo calamares 2>&1 | tee /tmp/ken/calamares.log
```

Setelah gagal:

```bash
journalctl -b --no-pager | grep -iE "calamares|shellprocess" | tail -200
tail -100 /tmp/ken/calamares.log
cat /etc/calamares/modules/shellprocess.conf     # perintah apa yang jalan
```

**Di UI Calamares**: halaman error biasanya punya tombol **"Details" / "Details ↗"** — itu isinya log. **Screenshot sebelum nutup window-nya.**

---

### D. `grub-mkconfig` timeout — error LAMA, harusnya udah ke-fix

Fix-nya `timeout: 600` (sebelumnya 120), dari paket `calamares-config-koppie-1.0.0-3`.

Cek di live:

```bash
grep -n "grub-mkconfig" -A2 -B2 /etc/calamares/modules/shellprocess.conf
# harus kelihatan:
#   - command: grub-mkconfig -o /boot/grub/grub.cfg
#     timeout: 600
pacman -Q calamares-config-koppie        # harus 1.0.0-3
```

Kalau **masih timeout di 600**, berarti `os-prober` nemu sesuatu yang bikin `grub-mkconfig` menggantung. Kumpulin:

```bash
journalctl -b --no-pager | grep -iE "os-prober|grub" | tail -100
lsblk -f                                     # disk apa aja yang ke-scan
# tes manual di live (butuh waktu — ini persis yang bikin lambat):
timeout 600 os-prober --target=x86_64-efi ; echo "exit=$?"
```

---

### E. Install KELAR tapi gak ada menu GRUB / gak ke-detek OS lain

Ini skenario dualboot. Boot dari USB lagi ke live, lalu chroot:

```bash
lsblk -f          # kenali: partisi ROOT target & partisi EFI

# --- UEFI (kebanyakan laptop sekarang) ---
sudo mount /dev/sdXN /mnt                      # ROOT target
sudo mount /dev/sdXP /mnt/boot/efi             # partisi EFI (FAT32, biasanya sda1/100-500MB)
# kalau /boot terpisah juga: sudo mount /dev/sdXM /mnt/boot
sudo mount --bind /dev  /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys  /mnt/sys
sudo arch-chroot /mnt

# --- di dalam chroot ---
grub-install --target=x86_64-efi \
             --efi-directory=/boot/efi \
             --bootloader-id=KOPPIE \
             --recheck

# pastiin os-prober nyala
grep -n GRUB_DISABLE_OS_PROBER /etc/default/grub
# kalau nggak ada / tertulis "true", paksa:
#   echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
grep -n "menuentry" /boot/grub/grub.cfg | head -20
exit
```

**BIOS/legacy** (MBR):

```bash
sudo mount /dev/sdXN /mnt
sudo mount --bind /dev /mnt/dev ; sudo mount --bind /proc /mnt/proc ; sudo mount --bind /sys /mnt/sys
sudo arch-chroot /mnt
grub-install --target=i386-pc /dev/sdX          # HARUS disk-nya (/dev/sda), BUKAN partisi
grub-mkconfig -o /boot/grub/grub.cfg
exit
```

**Kalau `grub-install` UEFI gagal**, tambah `--removable` — itu naro `EFI/BOOT/BOOTX64.EFI` yang pasti kebaca semua firmware:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
```

**Kalau entry OS lama gak muncul di `grub.cfg`**, tes os-prober-nya langsung di chroot:

```bash
os-prober --target=x86_64-efi ; echo "exit=$?"
# exit=0 dan ada output = prober jalan. Baris kosong = nggak ada OS lain terdeteksi.
#   → cek partisi OS lain ke-mount gak:  mount /dev/sdXY /mnt/os  lalu ulangi
```

Lepas chroot dengan aman sebelum reboot:

```bash
exit
sudo umount -R /mnt
sudo reboot
```

> **Peringatan**: `umount -R /mnt` harus sukses semua. Kalau ada yang `target is busy`, `sudo umount -lf -R /mnt`.

---

## 3b. Setelah install KELAR — 3 masalah pasca-install

Tiga skenario ini muncul **di sistem yang udah ke-install** (bukan di live), jadi jalankan semuanya dari Konsole di sistem terinstall.

### F. `pacman` gagal — `unable to lock database`

**Penyebab**: `/var/lib/pacman/db.lck` tertinggal karena proses pacman sebelumnya putus mendadak (laptop mati, internet putus, di-cancel paksa).

**KUNCI urutannya**: bunuh prosesnya **DULU**, baru hapus lock-nya. Kebalikan = lock bisa ke-create ulang.

```bash
# 1. Bunuh semua sisa proses pacman (DULU, biar lock-nya nggak dibuat lagi)
sudo killall pacman 2>/dev/null

# 2. Baru hapus lock yang menggantung
sudo rm -f /var/lib/pacman/db.lck

# 3. Bersihkan cache DB yang korup, lalu sinkronisasi ulang
sudo rm -f /var/lib/pacman/sync/*
sudo pacman -Syuu
```

> **Note**: Koppie **tidak memakai pamac**, jadi step "hapus lock pamac" tidak diperlukan di sini. Kalau `killall` bilang `no process found`, itu normal — lock-nya emang sisa file, bukan proses hidup.

---

### G. WiFi Broadcom mati (driver DKMS gagal build)

**Penyebab**: `broadcom-wl-dkms` (pakai **AUR**, bukan official repo) butuh `linux-lts-headers` yang **versinya persis sama** dengan kernel aktif. Kalau kernel ke-upgrade tapi headers nggak (atau kernel diganti ke non-LTS lalu balik lagi), driver gagal dikompilasi ulang oleh dkms.

> ISO Koppie **udah nyertakan** `linux-lts-headers` + `dkms`. Headers bisa hilang kalau sempat ke-uninstall waktu upgrade — makanya perintah di bawah aman dijalankan kapan pun.

**Butuh internet via USB tethering HP** (WiFi-kan lagi mati):

```bash
# 1. Sinkronkan + upgrade sekalian, BUKAN -Syy doang
#    (-Syy tanpa -u itu rawan "partial upgrade" di Arch)
sudo pacman -Syu linux-lts-headers

# 2. Lihat status driver (harusnya "broadcom-wl" terdaftar + status build)
dkms status

# 3. Kompilasi ulang semua modul DKMS ke kernel yang kepasang
sudo dkms autoinstall

# 4. Cek lagi — status harusnya "installed", BUKAN "broken"
dkms status

# 5. Muat driver + restart jaringan + REBOOT
sudo modprobe wl
sudo systemctl restart NetworkManager
sudo reboot
```

**Kalau `dkms status` masih "broken"**: `linux-lts-headers` versinya belum tentu sama dengan `uname -r`. Cocokkan dulu:

```bash
uname -r                              # versi kernel AKTIF, ex: 6.6.x-lts
pacman -Q linux-lts linux-lts-headers # versi yang kepasang
# kalau beda: sudo pacman -Syu   (samain semua dulu, baru ulangi langkah 2-5)
```

---

### H. OS lain gak muncul di menu GRUB (dualboot, setelah install selesai)

**PENTING — baca dulu sebelum nyalain os-prober**:

Di Koppie, os-prober **udah aktif dari sononya**. Faktanya dari ISO:

| Komponen | Status di Koppie |
|---|---|
| `os-prober` | udah terpasang (`packages.x86_64`) |
| `GRUB_DISABLE_OS_PROBER` | udah ditulis `"false"` sama modul `grubcfg` Calamares |

Jadi **"GRUB modern nge-disable os-prober" NGGAK berlaku di sini**. Kalau OS kedua tetap gak nongol, masalahnya BUKAN os-prober mati. Cek dua hal ini dulu:

**Kemungkinan 1 — yang keboot GRUB-nya OS kedua, bukan Koppie.**

```bash
efibootmgr -v          # bootloader mana yang jadi default?
# kalau entry-nya nunjuk Arch kedua (bukan "KOPPIE"), itu yang keboot duluan.
# Solusi: masuk BIOS, balikin boot order ke KOPPIE. Atau dari OS kedua:
#   sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi \
#        --bootloader-id=KOPPIE --recheck
```

**Kemungkinan 2 — grub-mkconfig terakhir jalan dari OS LAIN** (os-prober-nya masih default/off di sana), jadi `/boot/grub/grub.cfg` kepenuhan config OS itu dan entry Koppie/OS lain ilang. Fix-nya: **regenerate dari Koppie** (partition yang megang GRUB).

```bash
# dari Koppie, root mount di /
grep -n GRUB_DISABLE_OS_PROBER /etc/default/grub
# harusnya udah "false". Kalau belum, tambahin SEKALI (idempoten):
grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub \
  || echo 'GRUB_DISABLE_OS_PROBER=false' | sudo tee -a /etc/default/grub

sudo os-prober                  # tes deteksi — harusnya muncul daftar OS lain
sudo grub-mkconfig -o /boot/grub/grub.cfg
grep -n menuentry /boot/grub/grub.cfg | head   # entry OS lain harus kecantum
```

**Kalau `os-prober` kosong tapi OS-nya emang ada**: partisi OS lain gak ke-mount waktu `grub-mkconfig` jalan. Mount manual dulu (`sudo mount /dev/sdXY /mnt/os`), ulangi dari atas.

> `echo ... | tee -a` bisa nambah baris dobel kalau dijalankan 2x — makanya dibungkus `grep -q ... ||` biar cuma nulis kalau belum ada.

---

## 4. Urutan modul Calamares (biar tau tahap mana yang gagal)

```
show   : welcome  locale  keyboard  partition  users  summary
exec   : contextualprocess  partition  mount  unpackfs  machineid
         bootloader  fstab  locale  keyboard  localecfg  users
         displaymanager  networkcfg  hwclock  packages  grubcfg
         shellprocess  removeuser  umount
show   : finished            fail: umount
```

Tahap yang paling sering gagal → `unpackfs` (salin rootfs), `bootloader` (grub-install), `shellprocess` (mkinitcpio + grub-mkconfig).

Timeout per perintah di `shellprocess.conf`:

| perintah | timeout |
|---|---|
| `rm -f /etc/mkinitcpio.conf.d/archiso.conf` | 30 |
| guard `vmlinuz-linux-lts` | 60 |
| `mkinitcpio -P` | **900** |
| `grub-mkconfig -o /boot/grub/grub.cfg` | **600** ← fix-nya |
| sisanya (disable live user, dll) | 30 |

---

## 5. Minimal yang harus dikirim kalau minta tolong

1. **Teks error persis** (atau screenshot halaman error Calamares, tombol *Details*)
2. **`/tmp/ken/report.txt`** — atau minimal `head -120` + `grep -iE "error|fail|timeout"`
3. **`lsblk -f`** output
4. Sampai **tahap modul mana** Calamares berhenti (lihat bagian 4)

---

## 6. Yang SUDAH kebukti dari sisi ISO (jangan dicurigai lagi)

```
verify-iso.sh          29 OK / 0 FAIL / 0 WARN
sha512 ISO             4c5459d373b6d7b09a37076f4c061c3e00190f0ae388a4ca9c560465a1d69e1
                       06fe7ba5548f79c8d42018f18e3e54118883830f721ebaff3149c3bec6e2f6c13
burn ke flashdisk      byte-for-byte IDENTIK, MBR 55aa
grub timeout           600 dtk, kebaca di dalam sfs
baloo fix              /etc/systemd/user/kde-baloo.service.d/override.conf
                       Environment=QT_QPA_PLATFORM=offscreen  (identik dgn host, crash 3,3/dtk → 0)
plasma-welcome         6.8.0-1 + kded_plasma_welcome.so terpasang
os-prober              1.85-1 terpasang; grub 2.16 blokir HANYA kalau == "true"
grubcfg                nulis GRUB_DISABLE_OS_PROBER="false", GRUB_TIMEOUT=10,
                       GRUB_DISTRIBUTOR="Koppie Linux" ke /etc/default/grub target
urutan modul           bootloader → grubcfg → shellprocess(grub-mkconfig)
                       = config ke-enable SEBELUM grub-mkconfig jalan
ntfs-3g                ada → partisi Windows ke-detek
```

**Yang BELUM pernah kebukti** (semuanya baru terbukti setelah boot):

- ISO boot sampai Plymouth → SDDM → desktop
- `plasma-welcome` beneran muncul
- Calamares jalan sampai selesai
- `grub-mkconfig` tembus tanpa timeout
- Menu GRUB muncul + entry OS lama ke-detek
