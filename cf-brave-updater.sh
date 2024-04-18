#!/bin/bash
#-------------------------------------------------------------------------------
# Install and update script for Brave Browser stable (https://community.clearlinux.org/t/chrome-on-cl-again/9192/4)
# https://github.com/brave/brave-browser/releases
# Created by @marioroy, hacked by @paulcarroty for Clear Fraction Project
#-------------------------------------------------------------------------------

# shellcheck disable=SC2001,SC2143,SC2164

FILE="" URL="" VER=""

# Query for the latest release version for Linux, excluding pre-release.
for page in {1..3}; do
   RELVERs=$(curl -s https://brave-browser-apt-release.s3.brave.com/dists/stable/main/binary-amd64/Packages | grep -oP 'Version: \K(.*)' | head -n 10)
   if [ "$RELVERs" ]; then
      for VER in $RELVERs; do
         FILE="brave-browser_${VER}_amd64.deb"
         URL="https://github.com/brave/brave-browser/releases/download/v${VER}/brave-browser_${VER}_amd64.deb"
         # Check if the remote resource is available (or found), particularly the Linux RPM / DEB file.
         http_code=$(curl -o /dev/null --silent -Iw '%{http_code}' "$URL")
         if [ "$http_code" -eq "302" ]; then
            break
         else
            FILE="" URL=""
         fi
      done
   fi
   [ -n "$FILE" ] && break
done

if [ -z "$FILE" ]; then
   echo "ERROR: Cannot determine the latest release version"
   echo "https://github.com/brave/brave-browser/releases"
   exit 1
fi

NEW_VER="$VER"
BROWSER_EXE="/opt/3rd-party/bundles/clearfraction/opt/brave.com/brave/brave-browser"

if [[ -x "$BROWSER_EXE" ]]; then
   CUR_VER=$($BROWSER_EXE --version 2>/dev/null | awk '{ print $NF }')
else
   CUR_VER="not-installed"
fi

if [[ "${CUR_VER}" == *".${NEW_VER}"* ]]; then
   echo "Brave Browser stable $CUR_VER (current)"
   exit 0
elif [[ "$USER" == "root" ]]; then
   echo "Please run the script as a normal user, exiting..."
   exit 1
fi

# Test sudo, exit if wrong password or terminated.
echo "Test sudo, we need it to write new version into /opt"
sudo true >/dev/null || exit 2

# Install dependencies.
if [[ ! -x "/usr/bin/curl" || ! -x "/usr/bin/ar" ]]; then
   echo "Installing dependencies."
   sudo swupd bundle-add curl binutils --quiet
fi

#-------------------------------------------------------------------------------

if [[ ! -x "$BROWSER_EXE" ]]; then
   echo "Installing Brave Browser stable $NEW_VER"
else
   echo "Updating Brave Browser stable from $CUR_VER to $NEW_VER"
   # remove older installation via rpm
   [[ -f /usr/bin/rpm ]] && sudo rpm -e brave-browser 2>/dev/null
fi

cd /tmp

if [[ ! -f "$FILE" ]]; then
   curl -LO "$URL"
   if [[ ! -f "$FILE" || -n $(grep "^Not Found" "$FILE") ]]; then
      rm -f "$FILE"
      echo "ERROR: $FILE (No such file at download URL)"
      echo "https://github.com/brave/brave-browser/releases"
      exit 1
   fi
fi

mkdir -p /tmp/update.$$ && pushd /tmp/update.$$ >/dev/null
ar x /tmp/"$FILE" | 2>/dev/null
mkdir data && tar xf data.tar.* -C data
sudo rm -rf /opt/3rd-party/bundles/clearfraction/opt/brave.com/brave && sudo cp -ar data/opt/brave.com/brave /opt/3rd-party/bundles/clearfraction/opt/brave.com/ && echo "updated /opt/brave.com/brave..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/appdata/brave-browser.appdata.xml && sudo cp -ar data/usr/share/appdata/brave-browser.appdata.xml /opt/3rd-party/bundles/clearfraction/usr/share/appdata/brave-browser.appdata.xml && echo "updated brave-browser.appdata.xml..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/doc/brave-browser/changelog.gz && sudo cp -ar data/usr/share/doc/brave-browser/changelog.gz /opt/3rd-party/bundles/clearfraction/usr/share/doc/brave-browser/changelog.gz && echo "updated changelog.gz..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/gnome-control-center/default-apps/brave-browser.xml && sudo cp -ar data/usr/share/gnome-control-center/default-apps/brave-browser.xml /opt/3rd-party/bundles/clearfraction/usr/share/gnome-control-center/default-apps/brave-browser.xml && echo "updated gnome-control-center/default-apps/brave-browser.xml..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/man/man1/brave-browser*gz && sudo cp -ar data/usr/share/man/man1/brave-browser*gz /opt/3rd-party/bundles/clearfraction/usr/share/man/man1/ && echo "updated man1/brave-browser*gz..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/menu/brave-browser.menu && sudo cp -ar data/usr/share/menu/brave-browser.menu /opt/3rd-party/bundles/clearfraction/usr/share/menu/brave-browser.menu && echo "updated menu/brave-browser.menu"
[[ ! -x /opt/3rd-party/bundles/clearfraction/usr/share/applications/brave-browser.desktop ]] && cp -ar data/usr/share/applications/brave*.desktop /opt/3rd-party/bundles/clearfraction/usr/share/applications/

# sudo sed -i 's!/usr/bin/brave-browser-stable!/opt/brave.com/brave/brave-browser!g' \
#   /usr/share/applications/brave-browser.desktop
# sudo sed -i 's!^\(Exec=\)\(.*\)!\1env FONTCONFIG_PATH=/usr/share/defaults/fonts \2!g' \
#   /usr/share/applications/brave-browser.desktop

popd >/dev/null
rm -fr /tmp/update.$$

# Not needed in CF - handled by brave.desktop 
# Add icons to the system icons; installs to /usr/share/icons/hicolor/.
#for icon in \
#   product_logo_64.png product_logo_48.png product_logo_16.png product_logo_32.png \
#   product_logo_24.png product_logo_256.png product_logo_128.png
#do 
#   size=$(echo "$icon" | sed 's/[^0-9]//g')
#   sudo xdg-icon-resource install --size "$size" /opt/brave.com/brave/${icon} "brave-browser"
#done

sync
echo "OK"
