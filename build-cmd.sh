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

            cmake $(cygpath -w $src) -G"NMake Makefiles" $cmake_flags -DCMAKE_INSTALL_PREFIX=$(cygpath -w $stage) -DEXPAT_MSVC_STATIC_CRT=ON
            nmake
            nmake test
            nmake install

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.lib "$stage/lib/release/"
        ;;
        darwin*)
            opts="-arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE"
            plainopts="$(remove_cxxstd $opts)"
            export CFLAGS="$plainopts"
            export CXXFLAGS="$opts"
            export LDFLAGS="$plainopts"
            export CC="clang"
            export PREFIX="$stage"

            cmake $src $cmake_flags -DCMAKE_INSTALL_PREFIX=$stage
            make -j$AUTOBUILD_CPU_COUNT
            make test
            make install

            mkdir -p "$stage/lib/release"
            mv $stage/lib/*.a "$stage/lib/release/"
        ;;
        linux*)
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
