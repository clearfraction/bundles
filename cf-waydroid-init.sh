#!/bin/bash

# Check if running as root (sudo)
if [[ $EUID -ne 1000 ]]; then
    echo "This script must be run as user."
    exit 1
fi

# Determine Python version dynamically
# python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')

# Capture Environment variables excluding LS_COLORS and PYTHONPATH
env | grep -v '^LS_COLORS=' | grep -v '^PYTHONPATH=' > /tmp/waydroid

# Append PYTHONPATH to environment file
export PYTHONPATH=$(echo /opt/3rd-party/bundles/clearfraction/usr/lib/python*/)site-packages/)
echo "$PYTHONPATH" >> /tmp/waydroid
systemctl --user set-environment PYTHONPATH="$PYTHONPATH"
chmod -w /tmp/waydroid

# Trap to cleanup .env on EXIT
cleanup() {
    chmod +w /tmp/waydroid
    rm -f /tmp/waydroid
}
trap cleanup EXIT

# Function to initialize Waydroid based on user selection
initialize_waydroid() {
    case $1 in
        1) sudo waydroid init ;;
        2) sudo waydroid init -s GAPPS ;;
        *) return 1 ;;
    esac
}

# Load Waydroid environment variables
set -o allexport
source /tmp/waydroid
set +o allexport

# Main script
echo "Select an option:"
echo "1. Initialize Waydroid"
echo "2. Initialize Waydroid with GAPPS"
echo "3. Exit"

# Prompt user for choice
read -p "Enter your choice (1, 2, or 3): " choice

# Validate user input and call function
case $choice in
    1|2) initialize_waydroid $choice ;;
    *) echo "Exiting." ;;
esac

sudo sed -i '/^lxc\.apparmor\.profile/s/^/# /' /var/lib/waydroid/lxc/waydroid/config

# Enable and start waydroid-container.service
sudo systemctl enable waydroid-container.service
sudo systemctl start waydroid-container.service

# Check the status of waydroid-container.service
if ! systemctl is-active --quiet waydroid-container.service; then
    echo "waydroid-container.service failed to start. Exiting."
    sudo systemctl stop waydroid-container.service
    sudo systemctl disable waydroid-container.service
    exit 1
fi

exit 0
