#!/bin/bash
# docs - https://docs.01.org/clearlinux/latest/guides/clear/swupd-3rd-party.html

# Format bump detection
export CLR_FORMAT=$(curl --retry 3 https://download.clearlinux.org/update/$(curl --retry 3 https://download.clearlinux.org/latest)/format)
export CF_FORMAT=$(curl --retry 3 https://download.clearfraction.cf/update/$(curl --retry 3 https://download.clearfraction.cf/update/version/latest_version)/format) 
if [ "$CF_FORMAT" -eq "$CLR_FORMAT" ]; then
   echo "No format bump needed"
else 
   echo "Format bump needed"
   exit 1
fi


# Install the mixer tool and create workspace
swupd update --quiet
swupd bundle-add mixer package-utils git --quiet
swupd clean --all --quiet
shopt -s expand_aliases && alias dnf='dnf -q -y --releasever=latest --disableplugin=changelog,needs_restarting'
createrepo_c -q /home/artifact
dnf config-manager --add-repo https://cdn.download.clearlinux.org/current/x86_64/os \
                   --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64 \
                   --add-repo file:///home/artifact

curl --retry 3 -s https://api.github.com/repos/clearfraction/bundles/releases \
      | grep browser_download_url  | grep 'repo' \
      | cut -d '"' -f 4 | head -n 4 > /tmp/urls

export RELEASE=`curl --retry 3 -s https://download.clearlinux.org/latest`
export LAST_RELEASE=`head -1 /tmp/urls | cut -d '/' -f 8`
export MINIMAL_RELEASE=`tail -1 /tmp/urls | cut -d '/' -f 8`

# Import mixer config
curl --retry 3 -s -L https://github.com/clearfraction/bundles/releases/download/"$LAST_RELEASE"/mixer-"$LAST_RELEASE".tar -o /tmp/mixer.tar || { echo "Failed to download mixer state"; exit 1; }
tar xf /tmp/mixer.tar -C / && rm -rf /tmp/mixer.tar && cd /mixer
rm -rf bundles

# Import old releases to mixer
mkdir -p /mixer/update/{www,image}
tac /tmp/urls | while read url; do 
    curl --fail --retry 3 -s -LO "$url" && tar xf `basename $url` --strip-components=3 -C /mixer/update/www/ && rm -rf `basename $url`
    image=`echo $url | sed 's/repo/image/' | sed 's/.tar/.tar.zst/'`
    curl --fail --retry 3 -s -LO "$image" && tar xf `basename $image` --strip-components=3 -C /mixer/update/image/ && rm -rf `basename $image`   
done

# Create new mixer config
# mkdir ~/mixer && cd $_
# mixer init --no-default-bundles
# Configure `builder.conf` to set the default bundle, CONTENTURL, and VERSIONURL
# mixer config set Swupd.BUNDLE "os-core"
# mixer config set Swupd.CONTENTURL "https://clearfraction.herokuapp.com/update"
# mixer config set Swupd.VERSIONURL "https://clearfraction.herokuapp.com/update"
# Create an empty local os-core bundle. `swupd` client expects the os-core bundle to exist in a mix even if it’s empty.
# rm -rf /mixer/mixbundles /mixer/local-bundles/*
# mixer bundle create os-core --local


# Extract packages and manage content
git clone --quiet https://github.com/clearfraction/bundles.git
mv bundles/.git* /home && mv bundles/* /home
shopt -s extglob
rm -rf /mixer/mixbundles /mixer/local-bundles/!(os-core)
echo os-core > /mixer/mixbundles
pushd /home/configs
for bundle in *
 do
    dnf download --destdir=/tmp/"$bundle" `cat $bundle` || { echo "Failed to download $bundle content"; exit 1; }
    echo "content(/tmp/$bundle)" >> /mixer/local-bundles/$bundle
    for rpm in /tmp/"$bundle"/*.rpm; do rpm2cpio "$rpm" | cpio -D /tmp/"$bundle" -idm && rm -rf "$rpm"; done
    # handle AVX binaries
    [ -d /tmp/"$bundle"/V4 ] && rm -rf /tmp/"$bundle"/V4
    [ -d /tmp/"$bundle"/V3/usr/bin ] && cp -Rf /tmp/"$bundle"/V3/usr/bin/* /tmp/"$bundle"/usr/bin/
    [ -d /tmp/"$bundle"/V3/usr/lib64 ] && cp -Rf /tmp/"$bundle"/V3/usr/lib64/* /tmp/"$bundle"/usr/lib64/ 
    [ -d /tmp/"$bundle"/V3/usr/lib32 ] && cp -Rf /tmp/"$bundle"/V3/usr/lib32/* /tmp/"$bundle"/usr/lib32/ 
    [ -d /tmp/"$bundle"/V3/usr/libexec ] && cp -Rf /tmp/"$bundle"/V3/usr/libexec/* /tmp/"$bundle"/usr/libexec/
    [ -d /tmp/"$bundle"/V3 ] && rm -rf /tmp/"$bundle"/V3
    
    #fix pkgconfig
    [ -d /tmp/"$bundle"/usr/lib64/pkgconfig ] && sed -i 's|/usr|/opt/3rd-party/bundles/clearfraction/usr|g' /tmp/"$bundle"/usr/lib64/pkgconfig/*.pc
 done
popd

# Wipe legacy AVX* content
rm -rf /tmp/*/usr/share/clear/optimized-elf
find /tmp -depth -type d -name x86-64-v4 -exec rm -rf '{}' \;

# Python cleanup
find /tmp -depth -type d -name *.dist-info -exec rm -rf '{}' \; 

# Fix execs
sed -i '5s|/usr|/opt/3rd-party/bundles/clearfraction/usr|' /tmp/foliate/usr/bin/com.github.johnfactotum.Foliate
sed -i 's|Exec=com.github.johnfactotum.Foliate|Exec=env GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas/ GI_TYPELIB_PATH=/opt/3rd-party/bundles/clearfraction/usr/lib64/girepository-1.0 com.github.johnfactotum.Foliate|' /tmp/foliate/usr/share/applications/*Foliate.desktop

sed -i 's|Icon=brave-browser|Icon=/opt/3rd-party/bundles/clearfraction/opt/brave.com/brave/product_logo_128.png|' /tmp/brave/usr/share/applications/brave-browser.desktop
sed -i 's|Exec=/usr/bin/brave-browser-stable|Exec=/opt/3rd-party/bundles/clearfraction/opt/brave.com/brave/brave-browser --ozone-platform-hint=auto|g' /tmp/brave/usr/share/applications/brave-browser.desktop
curl -s -L https://raw.githubusercontent.com/clearfraction/bundles/master/cf-brave-updater.sh -o /tmp/brave/usr/bin/cf-brave-updater && chmod +x /tmp/brave/usr/bin/cf-brave-updater

sed -i 's|Icon=vscodium|Icon=/opt/3rd-party/bundles/clearfraction/usr/share/pixmaps/vscodium.png|g' /tmp/vscodium/usr/share/applications/codium*.desktop
sed -i 's|Exec=/usr/share/codium/codium|Exec=/opt/3rd-party/bundles/clearfraction/usr/share/codium/codium --ozone-platform-hint=auto|g' /tmp/vscodium/usr/share/applications/codium*.desktop
curl -s -L https://github.com/clearfraction/bundles/blob/master/cf-vscodium-updater.sh -o /tmp/vscodium/usr/bin/cf-vscodium-updater && chmod +x /tmp/brave/usr/bin/cf-vscodium-updater


sed -i 's|Exec=shotwell|Exec=env GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas/ shotwell|' /tmp/shotwell/usr/share/applications/*Shotwell*.desktop

sed -i 's|Exec=qt6ct|Exec=env QT_QPA_PLATFORMTHEME=qt6ct QT_PLUGIN_PATH=/opt/3rd-party/bundles/clearfraction/usr/lib64/qt5/plugins/ LD_LIBRARY_PATH=/opt/3rd-party/bundles/clearfraction/usr/lib64/:\$LD_LIBRARY_PATH /opt/3rd-party/bundles/clearfraction/usr/bin/qt6ct|' /tmp/qt6ct/usr/share/applications/qt6ct.desktop


# Fix Brave symbolic link
pushd /tmp/brave/usr/bin
ln -sf ../../opt/brave.com/brave/brave-browser brave-browser-stable
popd

# Fix VSCodium symbolic link
pushd /tmp/vscodium/usr/bin
ln -sf ../../usr/share/codium/bin/codium codium
popd

# Fix webapp-manager paths
sed -i "s|/usr/lib|env PYTHONPATH=/opt/3rd-party/bundles/clearfraction/usr/lib/webapp-manager GSETTINGS_SCHEMA_DIR=/opt/3rd-party/bundles/clearfraction/usr/share/glib-2.0/schemas GI_TYPELIB_PATH=/opt/3rd-party/bundles/clearfraction/usr/lib64/girepository-1.0 LD_LIBRARY_PATH=/opt/3rd-party/bundles/clearfraction/usr/lib64/:\$LD_LIBRARY_PATH /opt/3rd-party/bundles/clearfraction/usr/lib|" /tmp/webapp-manager/usr/bin/webapp-manager
sed -i "s|/usr/share|/opt/3rd-party/bundles/clearfraction/usr/share|g" /tmp/webapp-manager/usr/lib/webapp-manager/webapp-manager.py

# Add bundles to the mix
mixer bundle add `ls /mixer/local-bundles`
mixer versions update --mix-version $RELEASE --upstream-version $RELEASE --skip-format-check

# Format bump
# do not run `mixer versions update`, `build upstream-format` will handle it
# also commend `mixer build all`, `mixer build delta-packs`, `mixer build delta-manifests`
# two releases will be generated: +10 and +20, keep the latter in `!($RELEASE|version|xxxxx)`
# mixer build upstream-format --new-format 31
# export RELEASE=`cat mixversion`

# Build the bundles and generate the update content
mixer build all --min-version "$MINIMAL_RELEASE" --skip-format-check
# mixer build delta-packs     --previous-versions 2
# mixer build delta-manifests --previous-versions 4

# Generate artifacts
mkdir -p /tmp/repo/update
rm -rf /mixer/update/www/!($RELEASE|version)
rm -rf /mixer/update/image/!($RELEASE|LAST_VER)

mv /mixer/update/www/* /tmp/repo/update 2>&1 1>/dev/null
mv /mixer/update/image /tmp/repo/ 2>&1 1>/dev/null
tar cf /home/mixer-$RELEASE.tar /mixer
tar cf /home/repo-$RELEASE.tar /tmp/repo/update
tar --zstd -cf /home/image-$RELEASE.tar.zst /tmp/repo/image
mv /home/artifact /home/packages && tar cf /home/packages-$RELEASE.tar /home/packages

# Deploy to GH releases
cd /home
hub release create -m v$RELEASE $RELEASE || { echo "Fatal: tag already exists"; exit 1; }
for i in {1..10}; do 
  hub release edit $RELEASE -m v$RELEASE -a repo-$RELEASE.tar -a mixer-$RELEASE.tar -a packages-$RELEASE.tar -a image-$RELEASE.tar.zst && break
  sleep 100
done
