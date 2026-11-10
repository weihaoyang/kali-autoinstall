# VMware Fusion（Apple Silicon）完整步骤

以下命令在 macOS 上执行，Fusion Pro 26H1 已安装。

## 1. 生成自动安装 ISO

```bash
./scripts/build-iso.sh \
  -i ~/Downloads/kali-linux-2026.3-installer-netinst-arm64.iso \
  -o ~/VMs/kali-auto-arm64.iso \
  --disk /dev/sda
```

## 2. 创建虚拟机骨架

Fusion 自带 `vmcli`：

```bash
VMCLI="/Applications/VMware Fusion.app/Contents/Public/vmcli"
mkdir -p ~/VMs/Fusion
"$VMCLI" VM Create -n "Kali Linux" -d "$HOME/VMs/Fusion" -c arm-other5xlinux-64
```

会在 `~/VMs/Fusion` 下生成 `Kali Linux.vmx` 和一个较小的 vmdk。

## 3. 扩容磁盘

```bash
VD="/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager"
"$VD" -x 80GB "$HOME/VMs/Fusion/Kali Linux.vmdk"
```

## 4. 替换 vmx

用下面内容覆盖 `~/VMs/Fusion/Kali Linux.vmx`（按需修改 ISO 路径）：

```ini
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "22"
guestOS = "arm-other5xlinux-64"
firmware = "efi"
numvcpus = "4"
memsize = "8192"
nvram = "Kali Linux.nvram"
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
sata0:0.fileName = "Kali Linux.vmdk"
sata0:0.deviceType = "disk"
sata0:1.present = "TRUE"
sata0:1.fileName = "/Users/you/VMs/kali-auto-arm64.iso"
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
```

## 5. 启动

```bash
VMRUN="/Applications/VMware Fusion.app/Contents/Public/vmrun"
"$VMRUN" start "$HOME/VMs/Fusion/Kali Linux.vmx" gui
```

之后无需操作：GRUB 自动进入 Automated install，分区、装包、装 GRUB、重启全部自动。

## 6. 找到虚拟机 IP

```bash
cat "/Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf" | grep subnet
arp -an | grep 192.168.140
```

或者看 Fusion 窗口右上角的网络信息。

## 7. 可选：补工具链 / 打快照

```bash
scp scripts/provision.sh kali@192.168.140.129:/tmp/
ssh kali@192.168.140.129 "sudo bash /tmp/provision.sh"

"$VMRUN" snapshot "$HOME/VMs/Fusion/Kali Linux.vmx" baseline
```

回滚：

```bash
"$VMRUN" revertToSnapshot "$HOME/VMs/Fusion/Kali Linux.vmx" baseline
```

## 常见问题

**Q: 为什么不用 Kali 官网的 `kali-linux-*-vmware-amd64.7z`？**

那是 x86_64 镜像。Apple Silicon 上的 Fusion 只能虚拟化 arm64，没有 x86 模拟，
导入后开机会提示客户机操作系统不受支持。

**Q: UTM 里装？**

UTM 用 `Virtualize`，磁盘设备是 `/dev/vda`，生成 ISO 时加 `--disk /dev/vda`。
UTM 的虚拟网卡是 virtio，Kali 安装器能识别。

**Q: 想改桌面环境？**

`--desktop kali-desktop-kde` / `kali-desktop-gnome` / `kali-desktop-xfce`。
