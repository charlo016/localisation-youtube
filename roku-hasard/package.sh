#!/bin/sh
# Crée le fichier .zip à téléverser sur la Roku (mode développeur)
cd "$(dirname "$0")"
mkdir -p dist
rm -f dist/film-au-hasard.zip
zip -r -9 dist/film-au-hasard.zip manifest source components images web fonts sounds -x '*.DS_Store'
echo "OK -> dist/film-au-hasard.zip"
