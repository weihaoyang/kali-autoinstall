# kali-autoinstall

把 **Kali Linux 官方 netinst ISO** 一键改造成「开机即装、无需任何交互」的自动安装盘。

用 `preseed` 预置语言、键盘、网络、分区、账号、镜像源、SSH 和 guest tools，
再用 `xorriso` 重打包，保留原盘的双引导（BIOS + UEFI）。

适合：

- 反复重建安全实验环境（渗透 / CTF / 取证）
- Apple Silicon 上的 VMware Fusion、UTM、Parallels（arm64）
- x86 上的 VMware / VirtualBox / PVE（amd64）
- 批量给团队/学生发统一环境

> 只生成安装介质，不内置任何工具。装完系统后可选执行 `scripts/provision.sh` 补齐工具链。

## 快速开始

```bash
# 依赖
brew install xorriso          # macOS
# sudo apt install xorriso python3   # Debian/Ubuntu

# 1. 下载官方 netinst ISO（arm64 或 amd64 都行）
#    https://www.kali.org/get-kali/#kali-installer-images

# 2. 生成自动安装盘
./scripts/build-iso.sh \
  -i ~/Downloads/kali-linux-2026.3-installer-netinst-arm64.iso \
  -o kali-auto-arm64.iso
```

输出 ISO 挂到虚拟机光驱，开机后不需要按任何键，约 10–20 分钟自动装完并重启。

默认账号：

| 项 | 默认值 |
|---|---|
| 用户名 / 密码 | `kali` / `kali` |
| 主机名 | `kali` |
| 安装磁盘 | `/dev/sda`（VMware/SATA；UTM/virtio 用 `--disk /dev/vda`） |
| 镜像 | `mirrors.ustc.edu.cn/kali` |
| 时区 | `Asia/Shanghai` |
| 桌面 | `kali-desktop-xfce` |
| 额外软件 | `openssh-server`、`open-vm-tools`、`open-vm-tools-desktop` |

全部可改：

```bash
./scripts/build-iso.sh \
  -i kali-linux-2026.3-installer-netinst-arm64.iso \
  -o kali-auto-arm64.iso \
  --hostname lab01 \
  --user analyst \
  --password 'S3cret!' \
  --disk /dev/sda \
  --mirror-host mirrors.tuna.tsinghua.edu.cn \
  --timezone Asia/Shanghai \
  --desktop kali-desktop-xfce
```

`--help` 查看完整参数。

## 创建虚拟机

### VMware Fusion（Apple Silicon）

```bash
VMCLI="/Applications/VMware Fusion.app/Contents/Public/vmcli"

"$VMCLI" VM Create -n "Kali Linux" -d "$HOME/VMs/Fusion" -c arm-other5xlinux-64
# 然后编辑生成的 .vmx：4 vCPU / 8 GB / EFI / SATA 磁盘 / SATA 光驱 / vmxnet3 NAT
```

完整的 `.vmx` 模板和命令见 [docs/apple-silicon-fusion.md](docs/apple-silicon-fusion.md)。

> ⚠️ Apple Silicon 只能跑 **arm64** 客户机。Kali 官网的 `-vmware-amd64.7z` 预装镜像
> 是 x86_64 的，在 M 系列 Mac 上无法开机，必须用 arm64 的 netinst ISO 安装。

### 其他平台

- **x86 VMware / VirtualBox**：正常新建 Linux（Debian 系）虚拟机，挂载生成的 ISO。
- **UTM (Apple Silicon)**：`Virtualize` → `Other`，磁盘 `/dev/vda`，用 `--disk /dev/vda` 生成 ISO。
- **PVE / libvirt**：磁盘按实际设备名传 `--disk`。

## 安装完成后（可选）

补齐红队 + 蓝队工具：

```bash
scp scripts/provision.sh kali@<vm-ip>:/tmp/
ssh kali@<vm-ip> "sudo bash /tmp/provision.sh"
```

包含：`kali-linux-large`、取证/报告元包、Web/AD/口令/无线/逆向/Pwn/流量分析工具，
以及 `volatility3`、`certipy`、`bloodhound.py` 等 pipx 工具。

## 工作原理

1. 从官方 ISO 取出 `/boot/grub/grub.cfg` 和 `/simple-cdd/kali.preseed`。
2. 把 [preseed/extra.preseed](preseed/extra.preseed) 追加到 Kali 官方 preseed 之后
   （后写的键覆盖官方默认值）。
3. 修改 GRUB 第一个菜单项，加入：
   `auto=true priority=critical language=en country=CN locale=en_US.UTF-8 keymap=us`
   并设置 `timeout=1`，实现无人值守启动。
4. `xorriso -boot_image any replay` 重打包，保留原盘引导记录。

## 注意

- 生成的 ISO 含 Kali Linux 发行版内容，其授权遵循 Kali 及各软件包各自的许可证；
  本仓库只包含构建脚本，不分发 ISO。
- 默认密码仅用于本地实验环境，请勿直接用于联网/生产环境。
- 自动化安装会**清空目标磁盘**，确认 `--disk` 指向正确。
- 某些 Kali 仓库包（如 `zeek`）可能和最新 glibc 冲突，脚本里已改用 Docker 方案。

## 测试环境

- Kali 2026.3 netinst（arm64 / amd64）
- VMware Fusion Pro 26H1u1（Apple Silicon，macOS 27）
- xorriso 1.5.8

## License

MIT（仅限本仓库脚本）。Kali Linux 是 OffSec 的商标。
