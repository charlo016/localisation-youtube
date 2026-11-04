#!/bin/sh
# Crée le fichier .zip à téléverser sur la Roku (mode développeur)
cd "$(dirname "$0")"
mkdir -p dist
rm -f dist/what2watch.zip
zip -r -9 dist/what2watch.zip manifest source components images web fonts sounds -x '*.DS_Store'
echo "OK -> dist/what2watch.zip"
