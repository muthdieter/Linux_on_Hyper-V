#!/bin/bash

set -e

SCRIPT_NAME="Install_Linux_on_Hyper-V"
SCRIPT_VERSION="V_1_0_4"
SCRIPT_DATE="7.2025"
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
log "    Debian 12.10 "
log "    Mint 22.1 "
log "    CentOS 9 "
log "    opensuse LEAP 15.6"        


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
# 2. Define per-distro tasks
# ------------------------
case "$DISTRO_ID" in

    "linuxmint"|"ubuntu")
        PKG_INSTALL="sudo apt install -y"
        UPDATE_CMD="sudo apt update"
        PACKAGE_MANAGER="apt (nala)"

        # Ensure nala
        if ! command -v nala &> /dev/null; then
            echo "➡ Installing nala..."
            sudo apt update
            sudo apt install -y nala
        fi
        INSTALL="sudo nala install -y"
        ;;

    "debian"|"raspbian")
        PKG_INSTALL="sudo apt install -y"
        UPDATE_CMD="sudo apt update"
        INSTALL=$PKG_INSTALL
        PACKAGE_MANAGER="apt"
        ;;

    "opensuse-leap"|"sles"|"opensuse-tumbleweed")
        PKG_INSTALL="sudo zypper install -y"
        UPDATE_CMD="sudo zypper refresh"
        INSTALL=$PKG_INSTALL
        PACKAGE_MANAGER="zypper"
        ;;

    "rhel"|"fedora"|"centos")
        PKG_INSTALL="sudo dnf install -y"
        UPDATE_CMD="sudo dnf makecache"
        INSTALL=$PKG_INSTALL
        PACKAGE_MANAGER="dnf"
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
# 4. Install Packages (where available)
# ------------------------
echo "📦 Installing base packages..."

$INSTALL chromium || true
$INSTALL samba || true
$INSTALL cifs-utils || true
$INSTALL wsdd || true
$INSTALL wsdd2 || true
$INSTALL linux-image-extra-virtual || true  # Only available for some distros

# ------------------------
# 5. Flatpak + Flathub + RustDesk
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
# 6. Modify GRUB for Hyper-V (optional)
# ------------------------
if [ -f /etc/default/grub ]; then
    GRUB_FILE="/etc/default/grub"
    GRUB_PATTERN='^GRUB_CMDLINE_LINUX_DEFAULT='
    GRUB_NEW='GRUB_CMDLINE_LINUX_DEFAULT="quiet splash video=hyperv_fb:1920x1080"'

    echo "🛠 Updating GRUB configuration for Hyper-V resolution..."

    if grep -q "$GRUB_PATTERN" "$GRUB_FILE"; then
        sudo sed -i "/$GRUB_PATTERN/ s/^/#/" "$GRUB_FILE"
        echo "$GRUB_NEW" | sudo tee -a "$GRUB_FILE"
    else
        echo "$GRUB_NEW" | sudo tee -a "$GRUB_FILE"
    fi

    echo "🔄 Running update-grub..."
    if command -v update-grub &> /dev/null; then
        sudo update-grub
    elif command -v grub2-mkconfig &> /dev/null; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
fi

# ------------------------
# 7. Reboot System
# ------------------------
echo "🔁 Rebooting system in 5 seconds to apply changes..."
sleep 5
sudo reboot
