#!/bin/bash
export CLR_FORMAT=$(curl --retry 3 https://download.clearlinux.org/update/$(curl --retry 3 https://download.clearlinux.org/latest)/format)
export CF_FORMAT=$(curl --retry 3 https://clearfraction.vercel.app/update/$(curl --retry 3 https://clearfraction.vercel.app/update/version/latest_version)/format) 
if [ "$CF_FORMAT" -eq "$CLR_FORMAT" ]; then
   echo "No format bump needed"
   exit 0
else 
   echo "Format bump needed"
fi

swupd update --quiet --retry-delay=1
swupd bundle-add mixer package-utils git rsync --quiet
swupd 3rd-party add clearfraction https://clearfraction.vercel.app/update -F "$CF_FORMAT" -y

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

# Extract packages and manage content
git clone --quiet https://github.com/clearfraction/bundles.git
mv bundles/.git* /home && mv bundles/* /home
shopt -s extglob
rm -rf /mixer/mixbundles /mixer/local-bundles/!(os-core);
echo os-core > /mixer/mixbundles

pushd /home/configs
for bundle in *
do  
    swupd 3rd-party bundle-add "$bundle" -F "$CF_FORMAT" -y || { echo "Failed to install $bundle"; exit 1; }
    rsync -avz --exclude={'/usr/share/clear','/usr/share/defaults/swupd','/usr/lib/os-release'} /opt/3rd-party/bundles/clearfraction/* /tmp/"$bundle"/
    swupd 3rd-party bundle-remove "$bundle" -F "$CF_FORMAT"
    echo "content(/tmp/$bundle)" >> /mixer/local-bundles/$bundle
done
popd

# Cache cleanup
swupd clean --all && swupd 3rd-party clean --all

# Add bundles to the mix
mixer bundle add `ls /mixer/local-bundles`

# Format bump
# do not run `mixer versions update`, `build upstream-format` will handle it
# also commend `mixer build all`, `mixer build delta-packs`, `mixer build delta-manifests`
# two releases will be generated: +10 and +20, keep the latter in `!($RELEASE|version|xxxxx)`
# mixer build upstream-format --new-format 31

# Build the bundles and generate the update content
mixer build upstream-format


# Generate artifacts
mkdir -p /tmp/repo/update /tmp/repo/image /home/packages/empty
mv /mixer/update/www/{$((LAST_RELEASE+10)),$((LAST_RELEASE+20)),version} /tmp/repo/update/ && rm -rf /mixer/update/www/*
mv /mixer/update/image/{$((LAST_RELEASE+10)),$((LAST_RELEASE+20)),LAST_VER} /tmp/repo/image/ && rm -rf /mixer/update/image/*

for RELEASE in $((LAST_RELEASE+10)) $((LAST_RELEASE+20))
do
tar cf /home/mixer-$RELEASE.tar /mixer
tar cf /home/repo-$RELEASE.tar /tmp/repo/update
tar --zstd -cf /home/image-$RELEASE.tar.zst /tmp/repo/image
tar cf /home/packages-$RELEASE.tar /home/packages

# Deploy to GH releases
cd /home
hub release create -m v$RELEASE $RELEASE || { echo "Fatal: tag already exists"; exit 1; }
for i in {1..10}; do 
  hub release edit $RELEASE -m v$RELEASE -m "format bump" -a repo-$RELEASE.tar -a mixer-$RELEASE.tar -a packages-$RELEASE.tar -a image-$RELEASE.tar.zst && break
  sleep 100
done

done
echo "Artifacts:"
du -ch /home/*tar*


# Trigger the endpoint rebuild
curl -X POST ${VERCEL_REBUILD_HOOK}
