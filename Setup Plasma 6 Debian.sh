#!/bin/bash
# ---------------------------------------------------------------------------------------------------------------------
# Restore latest snapshot
# ---------------------------------------------------------------------------------------------------------------------
# sudo timeshift --restore --snapshot $(sudo timeshift --list | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}' | sort | tail -n 1) --grub /dev/nvme0n1
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
export LINUX_KERNEL_VER="linux-image-6.11.4-amd64"
export NVIDIA_DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/565.57.01/NVIDIA-Linux-x86_64-565.57.01.run"
# ---------------------------------------------------------------------------------------------------------------------
export TS_BASE_INSTALLATION="Base Installation"
export TS_ADD_UNSTABLE_SOURCES="Add Unstable Sources"
export TS_ADD_EXPERIMENTAL_SOURCES="Add Experimental Sources"
export TS_UPGRADE_KERNEL="Upgrade the kernel"
export TS_UPGRADE_KERNEL_PACKAGES="Post Kernel Upgrade Packages"
export TS_INSTALL_SDDM_AND_XORG="Install SDDM and XOrg"
export TS_INSTALL_PLASMA_DESKTOP="Install Plasma Desktop"
export TS_INSTALL_PLASMA_APPS="Install Plasma Apps"
export TS_BLACKLISTED_NOUVEAU="Blacklist default nvidia driver"
export TS_ADD_CONTRIB_SOURCES="Add Contrib and Non-free Sources"
export TS_INSTALL_NVIDIA_DRIVER_DEPENDENCIES="Install Nvidia Driver Dependencies"
export TS_INSTALL_NVIDIA_DRIVER="Install Nvidia Proprietary Driver"
export TS_POST_INSTALL_APPS="Post Setup Install Apps"
export TS_ENABLE_HDR="HDR Enable"
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
setupSudo() {
    su -c "/usr/bin/sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list"
    su -c "/usr/bin/apt-get -y install sudo"
    su -c "/usr/sbin/adduser $USER sudo"
    newgrp
}
# ---------------------------------------------------------------------------------------------------------------------
aptCleanup() {
    apt-get -y autoremove   || { exit 1; }
    apt-get -y clean        || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
fullUpgrade() {
    apt-get -y update       || { exit 1; }
    apt-get -y full-upgrade || { exit 1; }
    aptCleanup              || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
baseInstallation() {
    echo $TS_BASE_INSTALLATION
    # Get the system up to date on stable
    fullUpgrade ||  { exit 1; }

    # Install basic packages
    apt-get -y install openssh-server vim screen htop gcc make
    rm -rf /usr/bin/vi
    ln -s /etc/alternatives/vim /usr/bin/vi

    # Install Timeshift backup utility
    apt-get -y install timeshift --no-install-recommends
    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_BASE_INSTALLATION" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
addUnstableSources() {
    echo $TS_ADD_UNSTABLE_SOURCES
    echo | tee -a /etc/apt/sources.list
    echo 'deb http://deb.debian.org/debian sid main' | tee -a /etc/apt/sources.list
    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_ADD_UNSTABLE_SOURCES" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
addExpirementalSources() {
    echo $TS_ADD_EXPERIMENTAL_SOURCES
    echo 'deb http://deb.debian.org/debian experimental main' | tee -a /etc/apt/sources.list
    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_ADD_EXPERIMENTAL_SOURCES" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
upgradeKernel() {
    echo $TS_UPGRADE_KERNEL
    apt-get -y install $LINUX_KERNEL_VER
    timeshift --create --comments "$TS_UPGRADE_KERNEL" || { exit 1; }
    sudo reboot
}
# ---------------------------------------------------------------------------------------------------------------------
postKernelUpgradePackages() {
    echo $TS_UPGRADE_KERNEL_PACKAGES
    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_UPGRADE_KERNEL_PACKAGES" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
installSddmXOrg() {
    echo $TS_INSTALL_SDDM_AND_XORG
    apt-get -y -t sid install sddm xorg
    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_INSTALL_SDDM_AND_XORG" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
installPlasma6() {
    echo $TS_INSTALL_PLASMA_DESKTOP
    apt-get -y install -t experimental plasma-desktop
    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_INSTALL_PLASMA_DESKTOP" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
installPlasmaApps() {
    echo $TS_INSTALL_PLASMA_APPS

    apt-get -y install \
        dolphin \
        konsole \
        kate \
        firefox \
        gwenview \
        vlc

    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_INSTALL_PLASMA_APPS" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
disableNouveau() {
    echo $TS_BLACKLISTED_NOUVEAU
    echo 'blacklist nouveau' | tee /etc/modprobe.d/blacklist-nouveau.conf
    echo 'options nouveau modeset=0' | tee -a /etc/modprobe.d/blacklist-nouveau.conf
    update-initramfs -u
    timeshift --create --comments "$TS_BLACKLISTED_NOUVEAU" || { exit 1; }
    reboot
}
# ---------------------------------------------------------------------------------------------------------------------
addContribAndNonFreeSources() {
    echo $TS_ADD_CONTRIB_SOURCES

    dpkg --add-architecture i386 ||  { exit 1; }
    sed -i '/^deb/ {/contrib non-free/! s/$/ contrib non-free/}' /etc/apt/sources.list ||  { exit 1; }
    fullUpgrade ||  { exit 1; }

    timeshift --create --comments "$TS_ADD_CONTRIB_SOURCES" || { exit 1; }
    reboot
}
# ---------------------------------------------------------------------------------------------------------------------
installNvidiaDriverDependencies() {
    echo $TS_INSTALL_NVIDIA_DRIVER_DEPENDENCIES

    apt-get -y install linux-headers-$(uname -r) ||  { exit 1; }
    apt-get -y install pkg-config libglvnd-dev ||  { exit 1; }
    apt-get -y install libgl1:i386 libglx0:i386 libgcc-s1:i386 libc6:i386 ||  { exit 1; }

    timeshift --create --comments "$TS_INSTALL_NVIDIA_DRIVER_DEPENDENCIES" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
installNvidiaDriver() {
    echo $TS_INSTALL_NVIDIA_DRIVER

    NVIDIA_DRIVER=$(basename "$NVIDIA_DRIVER_URL")

    if [ ! -f "$NVIDIA_DRIVER" ]; then
        sudo -u $SUDO_USER wget "$NVIDIA_DRIVER_URL"
    fi

    chmod ugo+x $NVIDIA_DRIVER
    ./$NVIDIA_DRIVER || { echo "NVIDIA driver installation failed." >&2; exit 1; }

    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ nvidia-drm.fbdev=1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/g' /etc/default/grub ||  { exit 1; }
    echo 'export KWIN_DRM_ALLOW_NVIDIA_COLORSPACE=1' | tee -a /etc/environment
    echo 'export KWIN_DRM_USE_EGL_STREAMS=1' | tee -a /etc/environment
    echo 'export __GL_VRR_ALLOWED=1' | tee -a /etc/environment
    echo 'export __GL_GSYNC_ALLOWED=1' | tee -a /etc/environment

    update-grub || { exit 1; }
    aptCleanup || { exit 1; }
    timeshift --create --comments "$TS_INSTALL_NVIDIA_DRIVER" || { exit 1; }
    reboot
}
# ---------------------------------------------------------------------------------------------------------------------
postInstallApps() {
    echo $TS_POST_INSTALL_APPS
    sudo apt-get -y purge kwalletmanager ||  { exit 1; }
    sudo apt-get -y purge plasma-welcome ||  { exit 1; }

    sudo apt-get -y install net-tools zip unzip ||  { exit 1; }
    sudo apt-get -y install -t experimental filelight ||  { exit 1; }
    sudo apt-get -y install gimp mpv ||  { exit 1; }
    sudo apt-get -y install freerdp freerdp2-wayland remmina remmina-plugin-rdp ||  { exit 1; }

    if [ ! -f "xrdp-installer-1.5.2.sh" ]; then
        sudo -u $SUDO_USER wget "https://c-nergy.be/downloads/xRDP/xrdp-installer-1.5.2.zip"
        sudo -u $SUDO_USER unzip xrdp-installer-1.5.2.zip ||  { exit 1; }
        sudo rm -rf xrdp-installer-1.5.2.zip
        chmod ugo+x xrdp-installer-1.5.2.sh
    fi

    sudo -u $SUDO_USER xrdp-installer-1.5.2.sh ||  { exit 1; }
    firewall-cmd --permanent --add-port=3389/tcp ||  { exit 1; }
    firewall-cmd --reload ||  { exit 1; }

    if [ ! -f "sunshine-debian-bookworm-amd64.deb" ]; then
        sudo -u $SUDO_USER wget "https://github.com/LizardByte/Sunshine/releases/download/v0.23.1/sunshine-debian-bookworm-amd64.deb"
        chmod ugo+rwx ./sunshine-debian-bookworm-amd64.deb
    fi

    cp ./sunshine-debian-bookworm-amd64.deb /tmp/
    apt-get -y install /tmp/sunshine-debian-bookworm-amd64.deb || { exit 1; }
    rm -rf /tmp/sunshine-debian-bookworm-amd64.deb
    firewall-cmd --permanent --add-port=47989/tcp
    firewall-cmd --permanent --add-port=47984/tcp
    firewall-cmd --permanent --add-port=48010/tcp
    firewall-cmd --permanent --add-port=48010/udp
    firewall-cmd --permanent --add-port=48002/udp
    firewall-cmd --permanent --add-port=48000/udp
    firewall-cmd --permanent --add-port=47999/udp
    firewall-cmd --permanent --add-port=47998/udp
    firewall-cmd --reload ||  { exit 1; }

    fullUpgrade ||  { exit 1; }
    timeshift --create --comments "$TS_POST_INSTALL_APPS" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
enableHdr() {
    echo $TS_ENABLE_HDR
    KSCREEN=$(kscreen-doctor --outputs | grep Output | awk '$1=$1' | cut -d ' ' -f3)
    kscreen-doctor output.$KSCREEN.hdr.enable || { exit 1; }
    sudo timeshift --create --comments "$TS_ENABLE_HDR" || { exit 1; }
}
# ---------------------------------------------------------------------------------------------------------------------
main() {
    if [ "$(id -u)" -ne 0 ]; then
        if ! groups $USER | grep -q "\bsudo\b"; then
            setupSudo
            newgrp
        fi

        sudo "$0" "$@" || { echo "Installation Failed."; exit 1;}

#         if ! sudo timeshift --list | grep -q "$TS_ENABLE_HDR"; then
#             enableHdr || { echo "Set HDR Failed."; exit 1;}
#         fi

        exit $?
    fi

    echo "Starting Installation"

    if ! command -v timeshift &> /dev/null; then
        baseInstallation || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_ADD_UNSTABLE_SOURCES"; then
        addUnstableSources || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_ADD_EXPERIMENTAL_SOURCES"; then
        addExpirementalSources || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_UPGRADE_KERNEL"; then
        upgradeKernel || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_UPGRADE_KERNEL_PACKAGES"; then
        postKernelUpgradePackages || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_INSTALL_SDDM_AND_XORG"; then
        installSddmXOrg || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_INSTALL_PLASMA_DESKTOP"; then
        installPlasma6 || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_INSTALL_PLASMA_APPS"; then
        installPlasmaApps || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_BLACKLISTED_NOUVEAU"; then
        disableNouveau || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_ADD_CONTRIB_SOURCES"; then
        addContribAndNonFreeSources || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_INSTALL_NVIDIA_DRIVER_DEPENDENCIES"; then
        installNvidiaDriverDependencies || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_INSTALL_NVIDIA_DRIVER"; then
        installNvidiaDriver || { exit 1; }
    fi

    if ! timeshift --list | grep -q "$TS_POST_INSTALL_APPS"; then
        postInstallApps || { exit 1; }
    fi

    echo Installation Complete.
}
# ---------------------------------------------------------------------------------------------------------------------
main
# ---------------------------------------------------------------------------------------------------------------------
