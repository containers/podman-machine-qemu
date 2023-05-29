#!/bin/bash

set -exu

PREFIX="/tmp/bar\ foo"

! [ -d "${PREFIX}" ] && mkdir -p "${PREFIX}"

export LIBRARY_PATH="${PREFIX}"/lib
export CPATH="${PREFIX}"/include
export PKG_CONFIG_PATH="${LIBRARY_PATH}"/pkgconfig
export CPPFLAGS=-I"${PREFIX}"/include
export LDFLAGS=-L"${PREFIX}"/lib

QEMU_SOURCE_URL="https://download.qemu.org/qemu-8.0.0.tar.xz"


## Install following build time dependencies from brew:
## automake, autoconf, libtool, cmake, meson, ninja, curl, pkg-config

source build.sh

function build_qemu_deps() {
    build_lib_gettext "$1"
    build_lib_libffi "$1"
    build_lib_pcre2 "$1"
    # glib should always follow the above dependencies (order matters)
    build_lib_glib "$1"

    build_lib_gmp "$1"
    build_lib_gpgerror "$1"
    build_lib_gcrypt "$1"
    build_lib_nettle "$1"
    build_lib_libpng "$1"
    build_lib_jpeg "$1"
    build_lib_pixman "$1"
    build_lib_libslirp "$1"
    build_lib_libusb "$1"
    build_lib_lzo "$1"
    build_lib_snappy "$1"
    build_lib_vde2 "$1"
}

function build_qemu() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/qemu.rb
    build_qemu_deps "${PREFIX}" || exit

    export LIBTOOL=glibtool
    local source_dir
    source_dir=$(download_and_extract "${QEMU_SOURCE_URL}")

    local qemu_target
    local macos_version_min_flags
    case "$(uname -m)" in
         "x86_64")
             qemu_target="x86_64-softmmu"
             macos_version_min_flags="-mmacosx-version-min=10.15"
             export MACOSX_DEPLOYMENT_TARGET=10.15
             ;;
         "arm64")
             qemu_target="aarch64-softmmu"
             macos_version_min_flags="-mmacosx-version-min=11.0"
             export MACOSX_DEPLOYMENT_TARGET=11.0
             ;;
         *)
             echo "Unknown arch, exiting"
             exit 1
             ;;
    esac

    pushd "${source_dir}"
    export PATH=${PREFIX}/bin:${PATH}
    export CPPFLAGS="${CPPFLAGS} ${macos_version_min_flags}"
    export CFLAGS="${macos_version_min_flags}"
    ./configure --disable-bsd-user --disable-guest-agent --disable-curses --disable-libssh --disable-gnutls --enable-vde \
        --enable-virtfs --disable-sdl --enable-cocoa --disable-curses --disable-gtk --disable-zstd --enable-gcrypt \
        --disable-capstone --prefix="${PREFIX}" --target-list="${qemu_target}"

    make V=1 install
}

if build_qemu; then
    popd
    tar -C "${PREFIX}" -cJf qemu-macos-"${CPU}".tar.xz .
fi

