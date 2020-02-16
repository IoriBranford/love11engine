#!/bin/sh
set -e

PROJECT=${PROJECT:=${PWD##*/}}
PROJECT_TITLE=${PROJECT_TITLE:=${PROJECT}${GAME_TYPE}}
GAME_DIR=${GAME_DIR:="${PROJECT_TITLE}"}
GAME_TYPE=${GAME_TYPE:=game}
GAME_ASSET=${GAME_ASSET:=${GAME_TYPE}.love}
#PROJECT_ZIP=${PROJECT}-win${ARCH_BITS}.zip

ARCH_BITS=${ARCH_BITS:=64}
if [ ${ARCH_BITS} = 64 ]
then
	ARCH=x64
else
	ARCH=x86
fi

LOVE_VERSION=${LOVE_VERSION:="11.3"}
LOVE_DIR=love-${LOVE_VERSION}-win${ARCH_BITS}
LOVE_ZIP=${LOVE_DIR}.zip
LOVE_URL=https://bitbucket.org/rude/love/downloads/${LOVE_ZIP}

GME_VERSION=0.6.2
GME_MSVC=msvc12
GME_ZIP=libgme_${GME_VERSION}_${GME_MSVC}.zip
GME_URL=https://github.com/ShiftMediaProject/game-music-emu/releases/download/${GME_VERSION}/${GME_ZIP}

RESHACK_ZIP=resource_hacker.zip
RESHACK_URL=http://www.angusj.com/resourcehacker/${RESHACK_ZIP}

getZip () {
	ZIP=$1
	URL=$2
	wget -N ${URL}
	unzip -o ${ZIP} -d .
}

./make-game.sh
mkdir -p game-win

if ! [ -e ${LOVE_DIR} ]
then
	getZip ${LOVE_ZIP} ${LOVE_URL}
fi
cat ${LOVE_DIR}/lovec.exe ${GAME_ASSET} > game-win/${PROJECT}.exe
cp ${LOVE_DIR}/*.dll game-win

resHack () {
	xvfb-run wine ResourceHacker.exe -open game-win\\${PROJECT}.exe -save game-win\\${PROJECT}.exe $*
}

ICO=${ICO:=${LOVE_DIR}/game.ico}
if [ -e $ICO ]
then
	if ! [ -e ResourceHacker.exe ]
	then
		getZip ${RESHACK_ZIP} ${RESHACK_URL}
	fi
	resHack -action delete -mask ICONGROUP,,
	resHack -action add -res $ICO -mask ICONGROUP,MAINICON,
fi

if [ -e gme.dll ]
then
	if [ ${ARCH_BITS} = 64 ]
	then
		# custom build with MAME YM2612
		cp gme.dll game-win
	else
		if ! [ -e bin/${ARCH}/gme.dll ]
		then
			getZip ${GME_ZIP} ${GME_URL}
		fi
		cp bin/${ARCH}/gme.dll game-win
	fi
fi

if [ -e README.md ]
then
	cp README.md game-win
fi

mv game-win "${GAME_DIR}"