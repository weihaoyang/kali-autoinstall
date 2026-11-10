#!/usr/bin/env bash
#
# 可选：Kali 装好后再执行，补齐红队 + 蓝队/取证工具
# 用法: sudo bash provision.sh
#
set -uo pipefail

LOG=/var/log/kali-provision.log
exec > >(tee -a "$LOG") 2>&1

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

echo "===== Kali provision start: $(date) ====="

echo "[1/6] apt update & full-upgrade"
apt-get update
apt-get "${APT_OPTS[@]}" full-upgrade

echo "[2/6] Kali 大合集 + 取证/报告元包"
apt-get "${APT_OPTS[@]}" install kali-linux-large kali-tools-forensics kali-tools-reporting

echo "[3/6] 各方向补充工具"
PKGS=(
  # 信息收集 / 扫描
  nmap masscan arp-scan netdiscover whatweb nikto nuclei wpscan
  # Web / 漏洞利用
  burpsuite zaproxy sqlmap ffuf feroxbuster gobuster dirb
  metasploit-framework exploitdb
  # 口令 / 横向
  hashcat john hydra medusa seclists wordlists
  responder netexec impacket-scripts bloodhound bloodhound.py
  mitm6 enum4linux-ng evil-winrm
  # 网络 / 中间人
  wireshark tshark tcpdump termshark bettercap
  # 无线（需 USB 网卡直通）
  aircrack-ng kismet reaver wifite
  # 蓝队 / 取证 / 流量分析
  suricata autopsy sleuthkit guymager
  binwalk foremost scalpel yara bulk-extractor ewf-tools plaso
  chkrootkit rkhunter lynis clamav
  # 逆向 / PWN
  ghidra radare2 rizin gdb patchelf
  python3-pwntools qemu-user-static binutils
  # 基础设施
  docker.io openvpn wireguard-tools chisel ligolo-ng pipx
)
missing=()
for p in "${PKGS[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    apt-get "${APT_OPTS[@]}" install "$p" || missing+=("$p")
  else
    missing+=("$p")
  fi
done

echo "[4/6] 客户机增强"
apt-get "${APT_OPTS[@]}" install qemu-guest-agent spice-vdagent
systemctl enable --now qemu-guest-agent 2>/dev/null || true
systemctl enable --now spice-vdagent 2>/dev/null || true

echo "[5/6] pipx 补充工具"
if id kali >/dev/null 2>&1; then
  TARGET_USER=kali
else
  TARGET_USER=$(getent passwd 1000 | cut -d: -f1)
fi
for tool in pwncat-cs bloodyAD certipy-ad coercer lsassy volatility3; do
  sudo -u "$TARGET_USER" -H pipx install "$tool" 2>/dev/null \
    || sudo -u "$TARGET_USER" -H pipx upgrade "$tool" 2>/dev/null || true
done
echo 'export PATH=$PATH:$HOME/.local/bin' > /etc/profile.d/pipx.sh

echo "[6/6] 收尾"
if id "$TARGET_USER" >/dev/null 2>&1; then
  usermod -aG wireshark "$TARGET_USER" 2>/dev/null || true
  usermod -aG docker "$TARGET_USER" 2>/dev/null || true
fi
searchsploit -u >/dev/null 2>&1 || true
apt-get "${APT_OPTS[@]}" autoremove
apt-get clean

echo "===== 完成 $(date) ====="
if [ ${#missing[@]} -gt 0 ]; then
  echo "以下包在源中不存在或安装失败：${missing[*]}"
fi
echo "日志: $LOG"
echo "提示: 注销并重新登录，使 wireshark/docker 用户组生效。"

# Zeek: Kali 仓库版本可能与新 glibc 冲突，推荐 Docker
cat <<'EOT'

Zeek 可选（Docker）:
  docker pull zeek/zeek
  docker run --rm -v "$PWD:/pcap" -w /pcap zeek/zeek zeek -r test.pcap
EOT
