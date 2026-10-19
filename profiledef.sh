#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="koppie"
iso_label="KOPPIE_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Koppie Linux <https://github.com/maularaihan-git/koppie-repo>"
iso_application="Koppie Linux Live DVD"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="koppie"
bootmodes=('bios.syslinux'
           'uefi.grub')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/10-live"]="0:0:440"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/etc/polkit-1/rules.d/49-live-user.rules"]="0:0:644"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/koppie-live-user"]="0:0:755"
  ["/usr/local/bin/koppie-doctor"]="0:0:755"
  ["/usr/local/bin/koppie-lock-clean"]="0:0:755"
)
