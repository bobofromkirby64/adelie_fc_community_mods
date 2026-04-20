#!/bin/sh

mkdir bin
zip -9 -r -x'bin/*' bin/adeliefightclub.love .

curl -fsSL https://github.com/love2d/love/releases/download/11.5/love-11.5-macos.zip -o /tmp/love_macos.zip
unzip /tmp/love_macos.zip
mv love.app adeliefightclub.app
cp bin/adeliefightclub.love adeliefightclub.app/Contents/Resources
cp macos_Info.plist adeliefightclub.app/Contents/Info.plist

cp resources/graphics/icon.icns adeliefightclub.app/Contents/Resources/OS\ X\ AppIcon.icns

zip -y -9 -r bin/adeliefightclub_macos.zip adeliefightclub.app
rm -rf adeliefightclub.app

