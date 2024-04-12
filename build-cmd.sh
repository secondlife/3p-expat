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

cmake_flags="${CMAKE_FLAGS:--DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=Release}"

pushd $build
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            set +x
            load_vsvars
            set -x

            cmake $(cygpath -w $src) -G"Visual Studio 17 2022" $cmake_flags \
                -DCMAKE_INSTALL_PREFIX=$(cygpath -w $stage) \
                -DEXPAT_MSVC_STATIC_CRT=ON
            cmake --build .
            cmake --build . --target install

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.lib "$stage/lib/release/"
        ;;
        darwin*)
            export CFLAGS=$(remove_cxxstd $LL_BUILD_RELEASE)
            cmake $src -G"Xcode" $cmake_flags -DCMAKE_INSTALL_PREFIX=$stage
            cmake --build .
            cmake --build . --target install

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.a "$stage/lib/release/"
        ;;
        linux*)
            export CFLAGS=$(remove_cxxstd $LL_BUILD_RELEASE)
            cmake $src $cmake_flags -DCMAKE_INSTALL_PREFIX=$stage
            make -j$AUTOBUILD_CPU_COUNT
            make test
            make install

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.a "$stage/lib/release/"
        ;;
    esac

popd

mkdir -p "$stage/LICENSES"
mkdir -p "$stage/include/expat"
mv $stage/include/*.h "$stage/include/expat/"
cp "$src/COPYING" "$stage/LICENSES/expat.txt"
