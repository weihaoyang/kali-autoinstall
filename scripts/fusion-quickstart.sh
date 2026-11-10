#!/usr/bin/env bash
#
# macOS + VMware Fusion (Apple Silicon) 一键建 Kali 虚拟机并启动自动安装
#
set -euo pipefail

FUSION="/Applications/VMware Fusion.app"
VMCLI="$FUSION/Contents/Public/vmcli"
VMRUN="$FUSION/Contents/Public/vmrun"
VDISK="$FUSION/Contents/Library/vmware-vdiskmanager"

ISO=""
NAME="Kali Linux"
DIR="$HOME/VMs/Fusion"
CPUS=4
MEM_MB=8192
DISK_GB=80
START=1
GUEST_TYPE="arm-other5xlinux-64"

usage() {
  cat <<EOF
用法: $0 -i <自动安装 ISO> [选项]

必填:
  -i, --iso <path>        build-iso.sh 生成的 ISO

可选:
  -n, --name <name>       虚拟机名，默认 "Kali Linux"
  -d, --dir <dir>         存放目录，默认 ~/VMs/Fusion
      --cpus <n>          vCPU 数，默认 4
      --mem <mb>          内存 MB，默认 8192
      --disk <gb>         磁盘 GB，默认 80
      --no-start          只创建，不启动
  -h, --help

要求: macOS + VMware Fusion 已安装（vmcli / vmrun 随 Fusion 提供）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--iso) ISO="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -d|--dir) DIR="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --mem) MEM_MB="$2"; shift 2 ;;
    --disk) DISK_GB="$2"; shift 2 ;;
    --no-start) START=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || { echo "错误: 只支持 macOS" >&2; exit 1; }
[[ -d "$FUSION" ]] || { echo "错误: 未找到 VMware Fusion" >&2; exit 1; }
[[ -n "$ISO" && -f "$ISO" ]] || { echo "错误: 找不到 ISO，先用 build-iso.sh 生成" >&2; usage; exit 1; }
[[ "$(uname -m)" == "arm64" ]] || echo "提示: 当前不是 Apple Silicon，guestOS 可能不适用" >&2

VMX="$DIR/$NAME.vmx"
if [[ -e "$VMX" ]]; then
  echo "错误: 虚拟机已存在: $VMX" >&2
  exit 1
fi

mkdir -p "$DIR"

echo "[1/4] 创建虚拟机骨架"
"$VMCLI" VM Create -n "$NAME" -d "$DIR" -c "$GUEST_TYPE"

echo "[2/4] 扩容磁盘到 ${DISK_GB}GB"
"$VDISK" -x "${DISK_GB}GB" "$DIR/$NAME.vmdk" >/dev/null

echo "[3/4] 写入 vmx 配置"
cat > "$VMX" <<EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "22"
guestOS = "$GUEST_TYPE"
firmware = "efi"
numvcpus = "$CPUS"
memsize = "$MEM_MB"
nvram = "$NAME.nvram"
svga.present = "TRUE"
mks.enable3d = "TRUE"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"
hpet0.present = "TRUE"
usb_xhci.present = "TRUE"
ehci.present = "TRUE"
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "$NAME.vmdk"
sata0:0.deviceType = "disk"
sata0:1.present = "TRUE"
sata0:1.fileName = "$ISO"
sata0:1.deviceType = "cdrom-image"
sata0:1.startConnected = "TRUE"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "vmxnet3"
ethernet0.addressType = "generated"
ethernet0.startConnected = "TRUE"
tools.syncTime = "TRUE"
tools.upgrade.policy = "manual"
powerType.powerOff = "soft"
powerType.powerOn = "soft"
powerType.reset = "soft"
EOF

echo "[4/4] 完成"
echo "虚拟机: $VMX"
echo "规格:   ${CPUS} vCPU / ${MEM_MB} MB / ${DISK_GB} GB / EFI / NAT"
echo "ISO:    $ISO"

if [[ "$START" == "1" ]]; then
  echo "启动中（开机后会自动安装，无需操作）..."
  "$VMRUN" start "$VMX" gui
  echo "启动完成。安装结束后用默认账号 kali/kali 登录。"
else
  echo "已跳过启动：$VMRUN start \"$VMX\" gui"
fi
