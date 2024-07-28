#!/bin/bash
#-------------------------------------------------------------------------------
# Install and update script for VSCodium (https://community.clearlinux.org/t/chrome-on-cl-again/9192/4)
# Created by @marioroy, hacked by @paulcarroty for Clear Fraction Project
#-------------------------------------------------------------------------------

# shellcheck disable=SC2001,SC2143,SC2164

FILE="" URL="" VER=""

# Query for the latest release version for Linux, excluding pre-release.
for page in {1..2}; do
   RELVERs=$(curl -s https://api.github.com/repos/VSCodium/vscodium/tags | grep -oP '"name": "\K(.*)(?=")')
   if [ "$RELVERs" ]; then
      for VER in $RELVERs; do
         FILE="codium_${VER}_amd64.deb"
         URL="https://github.com/VSCodium/vscodium/releases/download/${VER}/codium_${VER}_amd64.deb"
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
BROWSER_EXE="/opt/3rd-party/bundles/clearfraction/usr/bin/codium"

if [[ -x "$BROWSER_EXE" ]]; then
   CUR_VER=$($BROWSER_EXE --version 2>/dev/null | sed '1p;d')
else
   CUR_VER="not-installed"
fi

if [[ "${CUR_VER}" == "${NEW_VER:0:6}" ]]; then
   echo "VSCodium stable $CUR_VER (current)"
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
   echo "Installing VSCodium stable $NEW_VER"
else
   echo "Updating VSCodium stable from $CUR_VER to $NEW_VER"
   # remove older installation via rpm
   [[ -f /usr/bin/rpm ]] && sudo rpm -e codium 2>/dev/null
fi

cd /tmp

if [[ ! -f "$FILE" ]]; then
   curl -LO "$URL"
   if [[ ! -f "$FILE" || -n $(grep "^Not Found" "$FILE") ]]; then
      rm -f "$FILE"
      echo "ERROR: $FILE (No such file at download URL)"
      echo "https://github.com/VSCodium/vscodium/releases"
      exit 1
   fi
fi

mkdir -p /tmp/update.$$ && pushd /tmp/update.$$ >/dev/null
ar x /tmp/"$FILE" | 2>/dev/null
mkdir data && tar xf data.tar.* -C data
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/codium && sudo cp -ar data/usr/share/codium /opt/3rd-party/bundles/clearfraction/usr/share/ && echo "updated usr/share/codium..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/appdata/brave-browser.appdata.xml && sudo cp -ar data/usr/share/appdata/codium.appdata.xml /opt/3rd-party/bundles/clearfraction/usr/share/appdata/codium.appdata.xml && echo "updated codium.appdata.xml..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/bash-completion/completions/codium && sudo cp -ar data/usr/share/bash-completion/completions/codium /opt/3rd-party/bundles/clearfraction/usr/share/bash-completion/completions/codium && echo "updated bash-completion..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/mime/packages/codium-workspace.xml && sudo cp -ar data/usr/share/mime/packages/codium-workspace.xml /opt/3rd-party/bundles/clearfraction/usr/share/mime/packages/codium-workspace.xml && echo "updated mime/packages/codium-workspace.xml..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/pixmaps/vscodium.png && sudo cp -ar data/usr/share/pixmaps/vscodium.png /opt/3rd-party/bundles/clearfraction/usr/share/pixmaps/vscodium.png && echo "updated logo..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/share/zsh && sudo cp -ar data/usr/share/zsh /opt/3rd-party/bundles/clearfraction/usr/share/ && echo "updated zsh completion..."

popd >/dev/null
rm -fr /tmp/update.$$

sync
echo "OK"
