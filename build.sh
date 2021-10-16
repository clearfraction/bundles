#!/bin/bash
# docs - https://docs.01.org/clearlinux/latest/guides/clear/swupd-3rd-party.html

# Install the mixer tool and create workspace
swupd update --quiet
swupd bundle-add mixer package-utils git --quiet 
shopt -s expand_aliases && alias dnf='dnf -q -y --releasever=latest --disableplugin=changelog,needs_restarting'
createrepo_c -q /home/artifact/
dnf config-manager --add-repo https://cdn.download.clearlinux.org/current/x86_64/os \
                   --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64 \
                   --add-repo file:///home/artifact


# Import mixer config
curl -s https://api.github.com/repos/clearfraction/bundles/releases/latest \
| grep browser_download_url \
| grep 'mixer' | cut -d '"' -f 4 \
| xargs -n 1 curl -L -o /tmp/mixer.tar || { echo "Failed to download mixer state"; exit 1; }
tar xf /tmp/mixer.tar -C / && rm -rf /tmp/mixer.tar && cd /mixer

# Create new mixer config
# mkdir ~/mixer && cd $_
# mixer init --no-default-bundles

# Configure `builder.conf` to set the default bundle, CONTENTURL, and VERSIONURL
mixer config set Swupd.BUNDLE "os-core"
mixer config set Swupd.CONTENTURL "https://clearfraction.herokuapp.com/update"
mixer config set Swupd.VERSIONURL "https://clearfraction.herokuapp.com/update"

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

# Fix execs
sed -i 's|/usr/share/|/opt/3rd-party/bundles/clearfraction/usr/share/|g' /tmp/passwordsafe/usr/bin/gnome-passwordsafe
sed -i 's|/usr/lib64/|/opt/3rd-party/bundles/clearfraction/usr/lib64/|g' /tmp/passwordsafe/usr/bin/gnome-passwordsafe
sed -i 's|Exec=gnome-passwordsafe|Exec=env GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas/ PYTHONPATH=$PYTHONPATH:/opt/3rd-party/bundles/clearfraction/usr/lib/python3.9/site-packages gnome-passwordsafe|' tmp/passwordsafe/usr/share/applications/*PasswordSafe.desktop

sed -i '5s|/usr|/opt/3rd-party/bundles/clearfraction/usr|' /tmp/foliate/usr/bin/com.github.johnfactotum.Foliate
sed -i 's|Exec=com.github.johnfactotum.Foliate|Exec=env GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas/ com.github.johnfactotum.Foliate|' tmp/foliate/usr/share/applications/*Foliate.desktop

ln -sf /tmp/brave/opt/brave.com/brave/brave-browser /opt/3rd-party/bundles/clearfraction/usr/bin/brave-browser-stable
sed -i 's|Icon=brave-browser|Icon=/opt/3rd-party/bundles/clearfraction/opt/brave.com/brave/product_logo_128.png|' /tmp/brave/usr/share/applications/brave-browser.desktop
sed -i 's|Exec=/usr/bin/brave-browser-stable|Exec=brave-browser-stable --enable-features=UseOzonePlatform --ozone-platform=wayland|g' /tmp/brave/usr/share/applications/brave-browser.desktop

sed -i 's|Icon=vscodium|Icon=/opt/3rd-party/bundles/clearfraction/usr/share/pixmaps/vscodium.png|g' /tmp/codium/usr/share/applications/codium*.desktop
sed -i 's|Exec=/usr/share/codium/codium|Exec=/opt/3rd-party/bundles/clearfraction/usr/share/codium/codium --enable-features=UseOzonePlatform --ozone-platform=wayland|g' /tmp/codium/usr/share/applications/codium*.desktop

sed -i 's|Exec=shotwell|Exec=env GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas/ shotwell|' tmp/shotwell/usr/share/applications/*Shotwell*.desktop
sed -i 's|Exec=fractal|Exec=env GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas/ fractal|' tmp/fractal/usr/share/applications/*Fractal.desktop
sed -i 's|Exec=shortwave|Exec=env GST_PLUGIN_PATH_1_0=/opt/3rd-party/bundles/clearfraction/usr/lib64/gstreamer-1.0 GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas shortwave|' tmp/shortwave/usr/share/applications/*Shortwave.desktop


# Add bundles to the mix
mixer bundle add `ls /mixer/local-bundles`

# Build the bundles and generate the update content
echo `curl -s https://download.clearlinux.org/latest` > /mixer/mixversion
mixer build bundles
mixer build update

# Generate artifacts
mkdir -p /tmp/repo/update
mv /mixer/update/www/* /tmp/repo/update && rm -rf /mixer/update 2>&1 1>/dev/null
export RELEASE=`cat /mixer/mixversion`
tar cf /home/mixer-$RELEASE.tar /mixer
tar cf /home/repo-$RELEASE.tar /tmp/repo
mv /home/artifact /home/packages && tar cf /home/packages-$RELEASE.tar /home/packages

# Deploy to GH releases
cd /home
hub release create -m v$RELEASE -a repo-$RELEASE.tar -a mixer-$RELEASE.tar -a packages-$RELEASE.tar $RELEASE


