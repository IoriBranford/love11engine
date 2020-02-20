#!/bin/sh
set -e

PROJECT=${PROJECT:=${PWD##*/}}
PROJECT_TITLE=${PROJECT_TITLE:=${PROJECT}${GAME_TYPE}}
GAME_TYPE=${GAME_TYPE:=game}
GAME_ASSET=${GAME_ASSET:=${GAME_TYPE}.love}
GAME_APP=${GAME_APP:="${PROJECT_TITLE}.app"}

CFBundleName=${CFBundleName:=${PROJECT_TITLE}}
CFBundleIdentifier=${CFBundleIdentifier:=org.unknown.${PROJECT}${GAME_TYPE}}
NSHumanReadableCopyright=${NSHumanReadableCopyright:="© 2xxx unknown"}

INSTALL_NAME_TOOL=${INSTALL_NAME_TOOL:=install_name_tool}

#PROJECT_ZIP=${PROJECT}-macosx.zip

LOVE_VERSION=${LOVE_VERSION:=11.3}
LOVE_APP=love.app
LOVE_ZIP=love-${LOVE_VERSION}-macos.zip
LOVE_URL=https://bitbucket.org/rude/love/downloads/${LOVE_ZIP}
# if bitbucket fails use temp Google Drive link
LOVE_APP_INFO=game.app/Contents/Info.plist
GAME_ASSET_PATH=game.app/Contents/Resources
GAME_LIB_PATH=game.app/Contents/Frameworks

./make-game.sh

# Download and extract the Mac version of LÖVE from the LÖVE homepage
if [ ! -e ${LOVE_APP} ]
then
	wget ${LOVE_URL} -O ${LOVE_ZIP}
	unzip ${LOVE_ZIP} -d .
fi

# Rename love.app to SuperGame.app
cp -r ${LOVE_APP} game.app

# Modify SuperGame.app/Contents/Info.plist
#patch -p0 < love-macosx-game.patch
#sed -i -e "s/myCFBundleIdentifier/${CFBundleIdentifier}/" ${LOVE_APP_INFO}
#sed -i -e "s/myCFBundleName/${CFBundleName}/" ${LOVE_APP_INFO}
#sed -i -e "s/myNSHumanReadableCopyright/${NSHumanReadableCopyright}/" ${LOVE_APP_INFO}

# Copy your SuperGame.love to SuperGame.app/Contents/Resources/
mkdir -p $GAME_ASSET_PATH
cp ${GAME_ASSET} ${GAME_ASSET_PATH}

# Extra libraries
getHomebrewDyLib() {
	PKG_NAME=$1
	PKG_VERSION=$2
	PKG_OSX_VERSION=el_capitan
	PKG_TAR_GZ=${PKG_NAME}-${PKG_VERSION}.${PKG_OSX_VERSION}.bottle.tar.gz
	PKG_URL=https://bintray.com/homebrew/bottles/download_file?file_path=${PKG_TAR_GZ}
	PKG_LIB=${PKG_NAME}/${PKG_VERSION}/lib
	if [ ! -f ${PKG_TAR_GZ} ]
	then wget ${PKG_URL} -O ${PKG_TAR_GZ}
	fi
	tar -zxf ${PKG_TAR_GZ} ${PKG_LIB}
	mv ${PKG_LIB}/*.dylib ${GAME_LIB_PATH}
}

#getHomebrewDyLib game-music-emu 0.6.2
#$INSTALL_NAME_TOOL -id @rpath/libgme.0.dylib ${GAME_LIB_PATH}/libgme.0.6.2.dylib

mv game.app "${GAME_APP}"

# Zip the SuperGame.app folder (e.g. to SuperGame_osx.zip) and distribute it.
# Enable the -y flag of zip to keep the symlinks.
#zip -y -r ${PROJECT_ZIP} "${GAME_APP}"