#!/bin/sh
set -e

GAME_ASSET=${GAME_ASSET:=game.love}

cd game
git ls-files | zip -9 ../$GAME_ASSET -@
cd ..
