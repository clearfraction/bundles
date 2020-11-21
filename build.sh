#!/bin/bash
# based on https://docs.01.org/clearlinux/latest/guides/clear/swupd-3rd-party.html

# Install the mixer tool and create workspace
swupd bundle-add mixer package-utils git 1>/dev/null
dnf config-manager --add-repo https://cdn.download.clearlinux.org/current/x86_64/os/ 1>/dev/null
dnf config-manager --add-repo https://gitlab.com/clearfraction/repository/raw/repos/ 1>/dev/null
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/ 1>/dev/null
dnf config-manager --add-repo https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/ 1>/dev/null

# Exit immediately if latest commit on tag
# git clone https://github.com/clearfraction/bundles.git /tmp/temprepo
# if [[ $(git -C /tmp/temprepo tag --points-at HEAD) ]]
#   then exit 0
#fi


# Import mixer config
curl -s https://api.github.com/repos/clearfraction/bundles/releases/latest \
| grep browser_download_url \
| grep 'mixer' | cut -d '"' -f 4 \
| xargs -n 1 curl -L -o /tmp/mixer.tar
tar xf /tmp/mixer.tar -C / && cd /mixer

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
    dnf download --destdir=/tmp/$bundle `cat $bundle`
    echo "content(/tmp/$bundle)" >> /mixer/local-bundles/$bundle
    for rpm in /tmp/$bundle/*.rpm; do rpm2cpio $rpm | cpio -D /tmp/$bundle -idm && rm -rf $rpm; done
done
popd

# Fix desktop entries
pushd /home/icons
apps='usr/share/applications'

mv  mpv.desktop             /tmp/codecs/$apps
mv *Foliate.desktop         /tmp/foliate/$apps
mv *meteo.desktop           /tmp/meteo/$apps
mv *PasswordSafe.desktop    /tmp/passwordsafe/$apps
mv *Shotwell*.desktop       /tmp/shotwell/$apps
mv *vocal.desktop           /tmp/vocal/$apps
mv *Shortwave.desktop       /tmp/shortwave/$apps
mv brave*.desktop           /tmp/brave/$apps
mv codium*.desktop          /tmp/vscodium/$apps
popd

# Fix execs
sed -i 's/\/usr\/share\//\/opt\/3rd-party\/bundles\/clearfraction\/usr\/share\//g' /tmp/passwordsafe/usr/bin/gnome-passwordsafe
sed -i 's/\/usr\/lib64\//\/opt\/3rd-party\/bundles\/clearfraction\/usr\/lib64\//g' /tmp/passwordsafe/usr/bin/gnome-passwordsafe
sed -i 's/"\/usr/"\/opt\/3rd-party\/bundles\/clearfraction\/usr/g' /tmp/foliate/usr/bin/com.github.johnfactotum.Foliate


# Add bundles to the mix
mixer bundle add `ls /mixer/local-bundles`

# Build the bundles and generate the update content
mixer versions update
mixer build bundles
mixer build update


# Collect old manifests
curl -s https://api.github.com/repos/clearfraction/bundles/releases \
   | grep browser_download_url \
   | grep 'repo' \
   | cut -d '"' -f 4 > urls
 
mkdir /tmp/old-manifests
cat urls | while read line
do 
    curl -LO $line
    file=`basename $line`
	 ver=`echo $file | sed -e s/[^0-9]//g`
	 tar -xf $file tmp/repo/update/$ver && rm -f $file
	 mv tmp/repo/update/$ver /tmp/old-manifests
	 rm -rf tmp /tmp/old-manifests/$ver/files 2>/dev/null 1>/dev/null
	 rm -rf /tmp/old-manifests/$ver/delta 2>/dev/null 1>/dev/null
	 rm -rf /tmp/old-manifests/$ver/*.tar 2>/dev/null 1>/dev/null	 
done

# Generate artifacts
mkdir -p /tmp/repo/update
mv /tmp/old-manifests/* /tmp/repo/update
mv /mixer/update/www/* /tmp/repo/update && rm -rf /mixer/update 2>/dev/null 1>/dev/null
tar cf /tmp/mixer.tar /mixer
tar cf /tmp/repo.tar /tmp/repo

# Deploy to GH releases
# curl -L https://github.com/github-release/github-release/releases/download/v0.8.1/linux-amd64-github-release.bz2 -o /tmp/release.bz2
# bzip2 -d /tmp/*bz2 && chmod +x /tmp/release && mv /tmp/release /usr/bin/gr
export RELEASE=`cat /mixer/mixversion`
# gr release --user clearfraction --repo bundles --tag $RELEASE --name v$RELEASE --description 'new release'
# gr upload  --user clearfraction --repo bundles --tag $RELEASE --name mixer-$RELEASE.tar --file /tmp/mixer.tar
# gr upload  --user clearfraction --repo bundles --tag $RELEASE --name repo-$RELEASE.tar --file /tmp/repo.tar

# Trigger GL CI
# curl -v -X POST -F token=$GL_TRIGGER -F ref=master https://gitlab.com/api/v4/projects/19115836/trigger/pipeline




