#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

FONTCONFIG_VERSION=2.11.0
FONTCONFIG_SOURCE_DIR="fontconfig"


# load autobuild provided shell functions and variables
eval "$("$AUTOBUILD" source_environment)"

stage="$(pwd)/stage"

echo "${FONTCONFIG_VERSION}" > "${stage}/VERSION.txt"

ZLIB_INCLUDE="${stage}"/packages/include/zlib

[ -f "$ZLIB_INCLUDE"/zlib.h ] || fail "You haven't installed the zlib package yet."

pushd "$FONTCONFIG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "linux")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 64-bit
            opts="${TARGET_OPTS:--m32}"
            HARDENED="-fstack-protector -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS" 
            fi

            fix_pkgconfig_prefix "$stage/packages"

            # First debug

            # Fontconfig is a strange one.  We use it in the Linux build and we ship it
            # but we ship the .so in a way that it isn't used in an installation.  Worse,
            # a casual build can export other libraries and we don't want that.  So,
            # we carefully build .so's here that we won't activate and which won't damage
            # the library resolution logic when this library is used with either shipped
            # products (viewer) or unit tests (namely INTEGRATION_TEST_llurlentry).
            # A better fix is to build this right and use it or just remove it (and
            # freetype).

            # Anyway, configure-time debug LDFLAGS references both debug and release
            # as source packages may only have release.  --disable-silent-rules is
            # present for chatty log files so you can review the actual library link
            # and confirm it's sane.  Point configuration to use libexpat from
            # dependent packages.  Make-time LDFLAGS adds an --exclude-libs option
            # to prevent re-export of archive symbols.

            CFLAGS="$opts -g -Og" \
                CXXFLAGS="$opts -g -Og" \
                LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype" \
                PKG_CONFIG_LIBDIR="$stage/packages/lib/debug/pkgconfig" \
                ./configure \
                --enable-static --enable-shared --disable-docs \
                --with-pic --disable-silent-rules \
                --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug/" --includedir="\${prefix}/include"
            make LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            make install DESTDIR="$stage" LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            fi

            make distclean 

            # Release last
            CFLAGS="$opts -g -O2 $HARDENED" \
                CXXFLAGS="$opts -g -O2 $HARDENED" \
                LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype" \
                PKG_CONFIG_LIBDIR="$stage/packages/lib/release/pkgconfig" \
                ./configure \
                --enable-static --enable-shared --disable-docs \
                --with-pic --disable-silent-rules \
                --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release/" --includedir="\${prefix}/include"
            make LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            make install DESTDIR="$stage" LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            fi

            make distclean 
        ;;

        "linux64")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 64-bit
            opts="${TARGET_OPTS:--m64}"
            HARDENED="-fstack-protector -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS" 
            fi

            fix_pkgconfig_prefix "$stage/packages"

            # First debug

            # Fontconfig is a strange one.  We use it in the Linux build and we ship it
            # but we ship the .so in a way that it isn't used in an installation.  Worse,
            # a casual build can export other libraries and we don't want that.  So,
            # we carefully build .so's here that we won't activate and which won't damage
            # the library resolution logic when this library is used with either shipped
            # products (viewer) or unit tests (namely INTEGRATION_TEST_llurlentry).
            # A better fix is to build this right and use it or just remove it (and
            # freetype).

            # Anyway, configure-time debug LDFLAGS references both debug and release
            # as source packages may only have release.  --disable-silent-rules is
            # present for chatty log files so you can review the actual library link
            # and confirm it's sane.  Point configuration to use libexpat from
            # dependent packages.  Make-time LDFLAGS adds an --exclude-libs option
            # to prevent re-export of archive symbols.

            CFLAGS="$opts -g -Og" \
                CXXFLAGS="$opts -g -Og" \
                LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype" \
                PKG_CONFIG_LIBDIR="$stage/packages/lib/debug/pkgconfig" \
                ./configure \
                --enable-static --enable-shared --disable-docs \
                --with-pic --disable-silent-rules \
                --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug/" --includedir="\${prefix}/include"
            make LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            make install DESTDIR="$stage" LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            fi

            make distclean 

            # Release last
            CFLAGS="$opts -g -O2 $HARDENED" \
                CXXFLAGS="$opts -g -O2 $HARDENED" \
                LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype" \
                PKG_CONFIG_LIBDIR="$stage/packages/lib/release/pkgconfig" \
                ./configure \
                --enable-static --enable-shared --disable-docs \
                --with-pic --disable-silent-rules \
                --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release/" --includedir="\${prefix}/include"
            make LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            make install DESTDIR="$stage" LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check LDFLAGS="$opts -g -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
            fi

            make distclean 
        ;;


        *)
            echo "build not supported."
            exit -1
        ;;
    esac

    mkdir -p "$stage/include"
    cp -a fontconfig "$stage/include"

    mkdir -p "$stage/LICENSES"
    cp COPYING "$stage/LICENSES/fontconfig.txt"
popd

mkdir -p "$stage"/docs/fontconfig/
cp -a README.Linden "$stage"/docs/fontconfig/

pass

