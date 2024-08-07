#!/usr/bin/env bash

set -eu

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

top="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
stage="$top/stage"
build="$top/build"
src="$top/libexpat/expat"

# load autbuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

mkdir -p $top
mkdir -p $build
mkdir -p $stage/LICENSES

cmake_flags="${CMAKE_FLAGS:--DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=Release}"

pushd $build
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            set +x
            load_vsvars
            set -x

            cmake $(cygpath -w $src) -G"Ninja Multi-Config" $cmake_flags -DCMAKE_INSTALL_PREFIX=$(cygpath -w $stage) -DEXPAT_MSVC_STATIC_CRT=OFF
            cmake --build . --config Release
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            cmake --install . --config Release

            mkdir -p "$stage/lib/release"
            mv $stage/lib/libexpatMD.lib "$stage/lib/release/libexpat.lib"
        ;;
        darwin*)
            opts="-arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE"
            plainopts="$(remove_cxxstd $opts)"

            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"

            cmake $src -G "Ninja Multi-Config" $cmake_flags -DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_C_FLAGS="$plainopts" -DCMAKE_CXX_FLAGS="$opts" -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}
            cmake --build . --config Release
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            cmake --install . --config Release

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.a "$stage/lib/release/"
        ;;
        linux*)
            opts="-m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE"
            plainopts="$(remove_cxxstd $opts)"

            cmake $src -G "Ninja" $cmake_flags -DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_C_FLAGS="$plainopts" -DCMAKE_CXX_FLAGS="$opts" -DCMAKE_BUILD_TYPE=Release
            cmake --build . --config Release
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ctest -C Release
            fi

            cmake --install . --config Release

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.a "$stage/lib/release/"
        ;;
    esac

popd

mkdir -p "$stage/LICENSES"
mkdir -p "$stage/include/expat"
mv $stage/include/*.h "$stage/include/expat/"
cp "$src/COPYING" "$stage/LICENSES/expat.txt"
