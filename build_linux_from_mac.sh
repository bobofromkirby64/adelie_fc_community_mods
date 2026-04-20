#!/bin/bash

mkdir -p bin
rm -f AFC.love
zip -9 -r AFC.love -x'bin/*' .

echo "Downloading LÖVE AppImage..."
curl -fsSL https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage -o /tmp/love.AppImage

echo "Scanning for SquashFS archive..."
rm -rf squashfs-root

OFFSETS=$(grep -aob "hsqs" /tmp/love.AppImage | cut -d: -f1)

SUCCESS=0
for OFFSET in $OFFSETS; do
    echo "Testing offset: $OFFSET bytes..."
    tail -c +$((OFFSET + 1)) /tmp/love.AppImage > /tmp/love.squashfs
    if unsquashfs -d squashfs-root /tmp/love.squashfs > /dev/null 2>&1; then
        echo "Valid SquashFS successfully extracted from offset $OFFSET!"
        SUCCESS=1
        break
    fi
done

if [ $SUCCESS -eq 0 ]; then
    echo "FATAL: Could not find a valid SquashFS superblock anywhere in the file."
    exit 1
fi

echo "Packaging Linux release..."
cat squashfs-root/bin/love AFC.love > squashfs-root/bin/adeliefightclub
chmod +x squashfs-root/bin/adeliefightclub

rm squashfs-root/bin/love
rm -f squashfs-root/AppRun squashfs-root/love.desktop squashfs-root/love.svg squashfs-root/.DirIcon
rm -f AFC.love /tmp/love.AppImage /tmp/love.squashfs

mv squashfs-root adeliefightclub

ln -s bin/adeliefightclub adeliefightclub/adeliefightclub

tar czvf bin/adeliefightclub_linux.tar.gz adeliefightclub/*
rm -rf adeliefightclub

echo "build complete: bin/adeliefightclub_linux.tar.gz"