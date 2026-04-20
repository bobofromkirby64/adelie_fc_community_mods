#!/bin/bash

mkdir bin
zip -9 -r AFC.love -x'bin/*' .

curl -fsSL https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage -o /tmp/love.AppImage

chmod +x /tmp/love.AppImage
/tmp/love.AppImage --appimage-extract
cat squashfs-root/bin/love AFC.love > squashfs-root/bin/adeliefightclub

chmod +x squashfs-root/bin/adeliefightclub

rm squashfs-root/bin/love
rm squashfs-root/AppRun
rm squashfs-root/love.desktop
rm squashfs-root/love.svg
rm squashfs-root/.DirIcon
rm AFC.love

mv squashfs-root adeliefightclub
ln -s bin/adeliefightclub adeliefightclub/adeliefightclub

tar czvf bin/adeliefightclub_linux.tar.gz adeliefightclub/*
rm -rf adeliefightclub
