#!/usr/bin/env bash

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about undefined vars
set -u

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

top="$(dirname "$0")"

STAGING_DIR="$(pwd)"

# load autbuild provided shell functions and variables
source_environment_tempfile="$STAGING_DIR/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

EXPAT_SOURCE_DIR="$(pwd)/../expat"
EXPAT_VERSION="$(sed -n -E "s/^ *PACKAGE_VERSION *= *'(.*)' *\$/\1/p" \
                     "$EXPAT_SOURCE_DIR/configure")"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${EXPAT_VERSION}.${build}" > "${STAGING_DIR}/VERSION.txt"

pushd "$EXPAT_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            set +x
            load_vsvars
            set -x

            msbuild.exe \
                -t:expat_static \
                -p:Configuration=Release \
                -p:Platform=$AUTOBUILD_WIN_VSPLATFORM \
                -p:PlatformToolset="${AUTOBUILD_WIN_VSTOOLSET:-v143}"

            BASE_DIR="$STAGING_DIR/"
            mkdir -p "$BASE_DIR/lib/release"
            cp win32/bin/Release/libexpatMT.lib "$BASE_DIR/lib/release/"

            INCLUDE_DIR="$STAGING_DIR/include/expat"
            mkdir -p "$INCLUDE_DIR"
            cp lib/expat.h "$INCLUDE_DIR"
            cp lib/expat_external.h "$INCLUDE_DIR"
        ;;
        darwin*)
            opts="-arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE"
            plainopts="$(remove_cxxstd $opts)"
            export CFLAGS="$plainopts"
            export CXXFLAGS="$opts"
            export LDFLAGS="$plainopts"
            export CC="clang"
            export PREFIX="$STAGING_DIR"
            if ! ./configure --prefix=$PREFIX
            then
                cat config.log >&2
                exit 1
            fi
            make -j$(nproc)
            make install

            mv "$PREFIX/lib" "$PREFIX/release"
            mkdir -p "$PREFIX/lib"
            mv "$PREFIX/release" "$PREFIX/lib"
            pushd "$PREFIX/lib/release"
            fix_dylib_id "libexpat.dylib"

            # CONFIG_FILE="$build_secrets_checkout/code-signing-osx/config.sh"
            # if [ -f "$CONFIG_FILE" ]; then
            #     source $CONFIG_FILE
            #     codesign --force --timestamp --sign "$APPLE_SIGNATURE" "libexpat.dylib"
            # else 
            #     echo "No config file found; skipping codesign."
            # fi
            # popd

            mv "$PREFIX/include" "$PREFIX/expat"
            mkdir -p "$PREFIX/include"
            mv "$PREFIX/expat" "$PREFIX/include"
        ;;
        linux*)
            PREFIX="$STAGING_DIR"
            CFLAGS="-m$AUTOBUILD_ADDRSIZE $(remove_cxxstd $LL_BUILD_RELEASE)" \
                  ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib/release"
            make -j$(nproc)
            make install

            mv "$PREFIX/include" "$PREFIX/expat"
            mkdir -p "$PREFIX/include"
            mv "$PREFIX/expat" "$PREFIX/include"
        ;;
    esac

    mkdir -p "$STAGING_DIR/LICENSES"
    cp "$EXPAT_SOURCE_DIR/COPYING" "$STAGING_DIR/LICENSES/expat.txt"
popd
