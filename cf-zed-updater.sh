#!/bin/bash
#-------------------------------------------------------------------------------
# The Update script for Zed on Clear Fraction
#-------------------------------------------------------------------------------

# shellcheck disable=SC2001,SC2143,SC2164

FILE="" URL="" VER=""

# Query for the latest release version for Linux, excluding pre-release.
for page in {1..2}; do
   RELVERs=$(curl -s https://api.github.com/repos/clearfraction/zed/tags | grep -oP '"name": "\K(.*)(?=")')
   if [ "$RELVERs" ]; then
      for VER in $RELVERs; do
         FILE="zed-${VER}.tar.gz"
         URL="https://github.com/clearfraction/zed/releases/download/${VER}/zed-${VER}.tar.gz"
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
   echo "https://github.com/clearfraction/zed/releases"
   exit 1
fi

NEW_VER="$VER"
BROWSER_EXE="/opt/3rd-party/bundles/clearfraction/usr/bin/zed"

if [[ -x "$BROWSER_EXE" ]]; then
   CUR_VER=$($BROWSER_EXE --version 2>/dev/null | grep -oP '[\d\.]+'))
else
   CUR_VER="not-installed"
fi

if [[ "${CUR_VER}" == "${NEW_VER:0:6}" ]]; then
   echo "Zed stable $CUR_VER (current)"
   exit 0
elif [[ "$USER" == "root" ]]; then
   echo "Please run the script as a normal user, exiting..."
   exit 1
fi

# Test sudo, exit if wrong password or terminated.
echo "Test sudo, we need it to write new version into /opt"
sudo true >/dev/null || exit 2

# Install dependencies.
if [[ ! -x "/usr/bin/curl" || ! -x "/usr/bin/tar" ]]; then
   echo "Installing dependencies."
   sudo swupd bundle-add curl binutils --quiet
fi

#-------------------------------------------------------------------------------

if [[ ! -x "$BROWSER_EXE" ]]; then
   echo "Installing Zed $NEW_VER"
else
   echo "Updating Zed from $CUR_VER to $NEW_VER"
   # remove older installation via rpm
   [[ -f /usr/bin/rpm ]] && sudo rpm -e zed 2>/dev/null
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
tar xf /tmp/"$FILE" | 2>/dev/null
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/bin/zed && sudo cp -ar zed-${VER}/usr/bin/zed /opt/3rd-party/bundles/clearfraction/usr/bin/ && echo "updated /usr/bin/zed..."
sudo rm -rf /opt/3rd-party/bundles/clearfraction/usr/libexec/zed-editor && sudo cp -ar zed-${VER}/usr/libexec/zed-editor /opt/3rd-party/bundles/clearfraction/usr/libexec/zed-editor && echo "updated usr/libexec/zed-editor..."

popd >/dev/null
rm -fr /tmp/update.$$

sync
echo "OK"
