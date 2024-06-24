#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Install required bundles
sudo swupd bundle-add kvm-host containers-basic

# Directory for kernel configuration
cmdline_dir="/etc/kernel/cmdline.d"
sudo mkdir -p "$cmdline_dir"

# Array for kernel params, change if needed.
kernel_params=(
    "systemd.unified_cgroup_hierarchy=1"
    "psi=1"
)

# Function to check if line already exists
line_checker() {
    for conf in "$cmdline_dir"/*.conf; do
        if [[ -f "$conf" ]] && grep -qFx "$1" "$conf"; then
            return 0  # Line found in at least one .conf file
        fi
    done
    return 1  # Line not found in any .conf file / no .conf files
}

# Iterate over array
for line in "${kernel_params[@]}"; do
    if ! line_checker "$line"; then
        echo "$line" | sudo tee -a "$cmdline_dir"/lxc.conf >/dev/null
    fi
done

# Update bootloader configuration
sudo clr-boot-manager update

# Enable libvirtd and additional services
sudo systemctl enable libvirtd libvirt-guests virtlxcd virtstoraged virtnetworkd virtnodedevd

# Array for creating symlinks, change if needed
files=(
    "/lib/systemd/system/lxc-monitord.service"
    "/lib/systemd/system/lxc-net.service"
    "/lib/systemd/system/lxc.service"
    "/lib/systemd/system/lxc@.service"
    "/lib/systemd/system/waydroid-container.service"
    "/lib/tmpfiles.d/lxc.conf"
    "/libexec/lxc/hooks/unmount-namespace"
    "/libexec/lxc/lxc-apparmor-load"
    "/libexec/lxc/lxc-containers"
    "/libexec/lxc/lxc-monitord"
    "/libexec/lxc/lxc-net"
    "/libexec/lxc/lxc-user-nic"
    "/sbin/init.lxc"
    "/share/dbus-1/system-services/id.waydro.Container.service"
    "/share/dbus-1/system.d/id.waydro.Container.conf"
    "/share/polkit-1/actions"
    "/share/lxc"
)

# Iterate over array
source_dir="/opt/3rd-party/bundles/clearfraction/usr"
target_dir="/usr"
for file in "${files[@]}"; do
    if [ -e "$source_dir$file" ]; then
        ln -sf "$source_dir$file" "$target_dir$file"
    else
        echo "File $source_dir$file does not exist."
    fi
done

echo "Setup complete. Restart for the bootloader configuration to take effect"
