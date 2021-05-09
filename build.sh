#!/bin/bash
# based on https://docs.01.org/clearlinux/latest/guides/clear/swupd-3rd-party.html

# Install the mixer tool and create workspace
swupd update --quiet
swupd bundle-add mixer package-utils git --quiet 
shopt -s expand_aliases && alias dnf='dnf -q -y --releasever=latest --disableplugin=changelog'
dnf config-manager --add-repo https://cdn.download.clearlinux.org/current/x86_64/os
dnf config-manager --add-repo https://gitlab.com/clearfraction/repository/raw/repos
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64


# Import mixer config
curl -s https://api.github.com/repos/clearfraction/bundles/releases/latest \
| grep browser_download_url \
| grep 'mixer' | cut -d '"' -f 4 \
| xargs -n 1 curl -L -o /tmp/mixer.tar
tar xf /tmp/mixer.tar -C / && rm -rf /tmp/mixer.tar && cd /mixer

# Create new mixer config
# mkdir ~/mixer && cd $_
# mixer init --no-default-bundles

# Configure `builder.conf` to set the default bundle, CONTENTURL, and VERSIONURL
mixer config set Swupd.BUNDLE "os-core"
mixer config set Swupd.CONTENTURL "https://clearfraction.gitlab.io/updates"
mixer config set Swupd.VERSIONURL "https://clearfraction.gitlab.io/updates"

# Create an empty local os-core bundle. `swupd` client expects the os-core bundle to exist in a mix even if it’s empty.
mixer bundle create os-core --local


# Extract packages and manage content
rm -rf /mixer/mixbundles
pushd /home/configs
for bundle in *
do
    dnf download --destdir=/tmp/$bundle `cat $bundle` || { echo "Failed to download $bundle content"; exit 1; }
    echo "content(/tmp/$bundle)" >> /mixer/local-bundles/$bundle
    for rpm in /tmp/$bundle/*.rpm; do rpm2cpio $rpm | cpio -D /tmp/$bundle -idm && rm -rf $rpm; done
done
popd

# Fix desktop entries
pushd /home/icons
apps='usr/share/applications'
mv  mpv.desktop             /tmp/codecs/$apps
mv *Foliate.desktop         /tmp/foliate/$apps
mv *PasswordSafe.desktop    /tmp/passwordsafe/$apps
mv *Shotwell*.desktop       /tmp/shotwell/$apps
mv *planner.desktop         /tmp/planner/$apps
mv *Shortwave.desktop       /tmp/shortwave/$apps
mv brave*.desktop           /tmp/brave/$apps
mv codium*.desktop          /tmp/vscodium/$apps
mv *Fractal.desktop         /tmp/fractal/$apps

popd

# Fix execs
sed -i 's|/usr|/opt/3rd-party/bundles/clearfraction/usr|g' /tmp/passwordsafe/usr/bin/gnome-passwordsafe
sed -i 's|/usr|/opt/3rd-party/bundles/clearfraction/usr|g' /tmp/foliate/usr/bin/com.github.johnfactotum.Foliate


# Add bundles to the mix
mixer bundle add `ls /mixer/local-bundles`

# Build the bundles and generate the update content
mixer versions update
mixer build bundles
mixer build update

# Generate artifacts
mkdir -p /tmp/repo/update
mv /mixer/update/www/* /tmp/repo/update && rm -rf /mixer/update 2>&1 1>/dev/null
export RELEASE=`cat /mixer/mixversion`
tar cf /home/mixer-$RELEASE.tar /mixer
tar cf /home/repo-$RELEASE.tar /tmp/repo

# Deploy to GH releases
cd /home
hub release create -m v$RELEASE -a repo-$RELEASE.tar -a mixer-$RELEASE.tar $RELEASE

# Trigger GL CI
curl -X POST -F token=$GL_TRIGGER -F ref=master https://gitlab.com/api/v4/projects/19115836/trigger/pipeline




