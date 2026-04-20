#!/bin/bash

mkdir bin
mkdir bin/windows
rm bin/adeliefightclub_windows.zip
zip -9 -r -x'bin/*' bin/adeliefightclub.love .

curl -fsSL https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip -o /tmp/love.zip
unzip /tmp/love.zip -d /tmp
cat /tmp/love-11.5-win64/love.exe bin/adeliefightclub.love > bin/windows/adeliefightclub.exe
cp /tmp/love-11.5-win64/{*.dll,license.txt} bin/windows
cd bin/windows
zip ../adeliefightclub_windows.zip -r .
cd ../..
rm -rf bin/windows
