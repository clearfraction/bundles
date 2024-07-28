#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

files=(
"/lib/systemd/user/xdg-desktop-portal-termfilechooser.service"
"/libexec/xdg-desktop-portal-termfilechooser"
"/share/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service"
"/share/xdg-desktop-portal/portals/termfilechooser.portal"
"/share/xdg-desktop-portal-termfilechooser/fzf-wrapper.sh"
"/share/xdg-desktop-portal-termfilechooser/lf-wrapper.sh"
"/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh"
"/share/xdg-desktop-portal-termfilechooser/ranger-wrapper.sh"
"/share/xdg-desktop-portal-termfilechooser/vifm-wrapper.sh"
)

# Iterate over array
source_dir="/opt/3rd-party/bundles/clearfraction/usr"
target_dir="/usr"
for file in "${files[@]}"; do
    if [ -e "$target_dir$file" ]; then
        echo "Removing symlink "$target_dir$file" --> "$source_dir$file""
        rm -rf "$target_dir$file"
    else
        echo "File $target_dir$file does not exist."
    fi
done
