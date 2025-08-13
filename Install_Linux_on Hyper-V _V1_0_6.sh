#!/bin/bash
set -e

SCRIPT_NAME="Install_Linux_on_Hyper-V"
SCRIPT_VERSION="V_1_0_6"
SCRIPT_DATE="8.2025"
SCRIPT_GITHUB="https://github.com/muthdieter"

function log() {
    echo -e "$1"
}

clear
log ""
log "             ____  __  __"
log "            |  _ \|  \/  |"
log "            | | | | |\/| |"
log "            | |_| | |  | |"
log "            |____/|_|  |_|"
log ""
log "  $SCRIPT_GITHUB"
log "  $SCRIPT_NAME"
log "  $SCRIPT_VERSION"
log "  $SCRIPT_DATE"
log ""
log "    tested on : "
log "    Debian 12.10, Mint 22.1, CentOS 9, openSUSE Leap 15.6"
log "    Arch Linux, Kali Linux, Pop-OS,Fedora"
log ""

read -p "Press Enter to continue..."

# ------------------------
# 1. Detect Distribution
# ------------------------
echo "🔍 Detecting Linux distribution..."
DISTRO_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
echo ""
echo "➡ Detected distribution: $DISTRO_ID"
echo ""
read -p "Press Enter to continue..."

# ------------------------
# 2. Define per-distro package commands
# ------------------------
case "$DISTRO_ID" in
    "linuxmint"|"ubuntu"|"kali"|"pop")
        UPDATE_CMD="sudo apt update"
        INSTALL="sudo apt install -y"
        PACKAGE_MANAGER="apt"
        ;;
    "debian"|"raspbian")
        UPDATE_CMD="sudo apt update"
        INSTALL="sudo apt install -y"
        PACKAGE_MANAGER="apt"
        ;;
    "opensuse-leap"|"sles"|"opensuse-tumbleweed")
        UPDATE_CMD="sudo zypper refresh"
        INSTALL="sudo zypper install -y"
        PACKAGE_MANAGER="zypper"
        ;;
    "rhel"|"fedora"|"centos")
        UPDATE_CMD="sudo dnf makecache"
        INSTALL="sudo dnf install -y"
        PACKAGE_MANAGER="dnf"
        ;;
    "arch"|"manjaro"|"cachyos")
        UPDATE_CMD="sudo pacman -Sy"
        INSTALL="sudo pacman -S --noconfirm"
        PACKAGE_MANAGER="pacman"
        ;;
    *)
        echo "❌ Unsupported distribution: $DISTRO_ID"
        exit 1
        ;;
esac

# ------------------------
# 3. Update Repositories
# ------------------------
echo "🔄 Updating package repositories using $PACKAGE_MANAGER..."
eval "$UPDATE_CMD"

# ------------------------
# 4. Install SSH if not present
# ------------------------
if ! command -v ssh &> /dev/null; then
    echo "📦 Installing OpenSSH server..."
    case "$DISTRO_ID" in
        "arch"|"manjaro")
            $INSTALL openssh
            sudo systemctl enable sshd --now
            ;;
        *)
            $INSTALL openssh-server
            sudo systemctl enable ssh --now || sudo systemctl enable sshd --now
            ;;
    esac
else
    echo "✅ SSH is already installed."
fi

# ------------------------
# 5. Ensure firewall tool exists
# ------------------------
if ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
    echo "⚠️ No firewall tool found — installing one..."
    case "$DISTRO_ID" in
        "linuxmint"|"ubuntu"|"debian"|"raspbian"|"kali"|"pop")
            $INSTALL ufw
            ;;
        "rhel"|"fedora"|"centos"|"opensuse-leap"|"sles"|"opensuse-tumbleweed")
            $INSTALL firewalld
            ;;
        "arch"|"manjaro"|"cachyos")
            $INSTALL ufw
            ;;
    esac
fi

# ------------------------
# 6. Open firewall for SSH
# ------------------------
if command -v ufw &> /dev/null; then
    echo "🔓 Opening SSH port in UFW firewall..."
    sudo ufw allow ssh
    sudo ufw --force enable
elif command -v firewall-cmd &> /dev/null; then
    echo "🔓 Opening SSH port in firewalld..."
    sudo systemctl enable firewalld --now
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --reload
else
    echo "⚠️ No firewall management tool detected, skipping."
fi

# ------------------------
# 7. Install base packages
# ------------------------
echo "📦 Installing base packages..."
$INSTALL chromium || true
$INSTALL samba || true
$INSTALL cifs-utils || true
$INSTALL wsdd || true
$INSTALL wsdd2 || true
$INSTALL linux-image-extra-virtual || true  # only on some distros

# ------------------------
# 8. Flatpak + RustDesk
# ------------------------
if ! command -v flatpak &> /dev/null; then
    echo "➡ Installing Flatpak..."
    $INSTALL flatpak
fi

if ! flatpak remotes | grep -q flathub; then
    echo "➡ Adding Flathub remote..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "📦 Installing RustDesk via Flatpak..."
sudo flatpak install -y flathub com.rustdesk.RustDesk

# ------------------------
# 9. Modify GRUB for Hyper-V resolution
# ------------------------
if [ -f /etc/default/grub ]; then
    GRUB_FILE="/etc/default/grub"
    GRUB_PATTERN='^GRUB_CMDLINE_LINUX_DEFAULT='
    GRUB_NEW='GRUB_CMDLINE_LINUX_DEFAULT="quiet splash video=hyperv_fb:1920x1080"'

    echo "🛠 Updating GRUB configuration..."
    if grep -q "$GRUB_PATTERN" "$GRUB_FILE"; then
        sudo sed -i "/$GRUB_PATTERN/ s/^/#/" "$GRUB_FILE"
    fi
    echo "$GRUB_NEW" | sudo tee -a "$GRUB_FILE"

    if command -v update-grub &> /dev/null; then
        sudo update-grub
    elif command -v grub2-mkconfig &> /dev/null; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
fi

# ------------------------
# 10. Reboot
# ------------------------
echo "🔁 Rebooting in 5 seconds..."
sleep 5
sudo reboot
