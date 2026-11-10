#!/usr/bin/env bash
#
# 从 Kali 官方 netinst ISO 生成“全自动安装盘”
#
# 原理：
#   1. 从官方 ISO 中取出 /boot/grub/grub.cfg 和 /simple-cdd/kali.preseed
#   2. 往 kali.preseed 追加无人值守答案（语言/键盘/分区/账号/镜像/SSH）
#   3. 改写 GRUB 默认菜单项，加入 auto=true、language=en 等内核参数
#   4. 用 xorriso 重打包，保留原盘的 BIOS + UEFI 引导
#
set -euo pipefail

ISO=""
OUT="kali-auto.iso"
VM_HOSTNAME="kali"
VM_USER="kali"
VM_PASS="kali"
MIRROR_HOST="mirrors.ustc.edu.cn"
MIRROR_DIR="/kali"
TIMEZONE="Asia/Shanghai"
DISK="/dev/sda"
DESKTOP="kali-desktop-xfce"
COUNTRY="CN"

usage() {
  cat <<EOF
用法: $0 -i <官方 netinst ISO> [-o <输出 ISO>] [选项]

必填:
  -i, --iso <path>         Kali 官方 netinst ISO（arm64 或 amd64）

可选:
  -o, --out <path>         输出 ISO，默认 kali-auto.iso
      --hostname <name>    主机名，默认 kali
      --user <name>        用户名，默认 kali
      --password <pass>    用户密码，默认 kali
      --mirror-host <h>    apt 镜像域名，默认 mirrors.ustc.edu.cn
      --mirror-dir <d>     镜像路径，默认 /kali
      --timezone <tz>      时区，默认 Asia/Shanghai
      --disk <dev>         安装磁盘，默认 /dev/sda（VMware/SATA）
                           UTM/virtio 用 /dev/vda
      --desktop <pkg>      桌面元包，默认 kali-desktop-xfce
      --country <cc>       国家代码，默认 CN
  -h, --help               显示帮助

依赖: xorriso (brew install xorriso / apt install xorriso)、python3

示例:
  $0 -i ~/Downloads/kali-linux-2026.3-installer-netinst-arm64.iso \\
     -o kali-auto-arm64.iso

注意: 生成的 ISO 仅用于你自己的授权环境；Kali Linux 的授权遵循其各自许可证。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--iso) ISO="$2"; shift 2 ;;
    -o|--out) OUT="$2"; shift 2 ;;
    --hostname) VM_HOSTNAME="$2"; shift 2 ;;
    --user) VM_USER="$2"; shift 2 ;;
    --password) VM_PASS="$2"; shift 2 ;;
    --mirror-host) MIRROR_HOST="$2"; shift 2 ;;
    --mirror-dir) MIRROR_DIR="$2"; shift 2 ;;
    --timezone) TIMEZONE="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --desktop) DESKTOP="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$ISO" && -f "$ISO" ]] || { echo "错误: 找不到 ISO: $ISO" >&2; usage; exit 1; }
command -v xorriso >/dev/null || { echo "错误: 需要 xorriso" >&2; exit 1; }
command -v python3 >/dev/null || { echo "错误: 需要 python3" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESEED_TPL="$SCRIPT_DIR/../preseed/extra.preseed"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[1/4] 从官方 ISO 提取配置"
xorriso -osirrox on -indev "$ISO" \
  -extract /boot/grub/grub.cfg "$WORK/grub.cfg" \
  -extract /simple-cdd/kali.preseed "$WORK/kali.preseed" \
  >/dev/null 2>&1
chmod u+w "$WORK/grub.cfg" "$WORK/kali.preseed"

echo "[2/4] 渲染 preseed"
sed -e "s|@HOSTNAME@|$VM_HOSTNAME|g" \
    -e "s|@USERNAME@|$VM_USER|g" \
    -e "s|@PASSWORD@|$VM_PASS|g" \
    -e "s|@MIRROR_HOST@|$MIRROR_HOST|g" \
    -e "s|@MIRROR_DIR@|$MIRROR_DIR|g" \
    -e "s|@TIMEZONE@|$TIMEZONE|g" \
    -e "s|@DISK@|$DISK|g" \
    -e "s|@DESKTOP@|$DESKTOP|g" \
    -e "s|@COUNTRY@|$COUNTRY|g" \
    "$PRESEED_TPL" > "$WORK/extra.preseed"

# 追加在 Kali 官方 preseed 之后，后者优先，覆盖官方默认值
cat "$WORK/kali.preseed" "$WORK/extra.preseed" > "$WORK/kali-profile.preseed"

echo "[3/4] 改写 GRUB 菜单"
python3 - "$WORK/grub.cfg" "$COUNTRY" <<'PY'
import sys
path, country = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()

if "set timeout=" not in s:
    s = s.replace("set menu_color_normal=cyan/blue",
                  "set timeout=1\nset default=0\nset menu_color_normal=cyan/blue", 1)

old = "preseed/file=/cdrom/simple-cdd/default.preseed simple-cdd/profiles=kali"
new = (old + " auto=true priority=critical"
             f" language=en country={country} locale=en_US.UTF-8 keymap=us")
if "auto=true" not in s:
    s = s.replace(old, new, 1)

open(path, "w", encoding="utf-8").write(s)
PY

echo "[4/4] 重新打包 ISO"
rm -f "$OUT"
xorriso -indev "$ISO" -outdev "$OUT" -boot_image any replay \
  -map "$WORK/kali-profile.preseed" /simple-cdd/kali.preseed \
  -map "$WORK/grub.cfg" /boot/grub/grub.cfg \
  2>&1 | grep -E "Written to medium|completed successfully|FAILURE" || true

if command -v sha256sum >/dev/null; then
  sha256sum "$OUT"
else
  shasum -a 256 "$OUT"
fi

echo "完成: $OUT"
echo "用户名: $VM_USER  密码: $VM_PASS  磁盘: $DISK"
