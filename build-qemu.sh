#!/bin/bash

set -exu

PREFIX=${PREFIX:-/opt/podman/qemu}

! [ -d "${PREFIX}" ] && mkdir -p "${PREFIX}"

export LIBRARY_PATH="${PREFIX}"/lib
export CPATH="${PREFIX}"/include
export PKG_CONFIG_PATH="${LIBRARY_PATH}"/pkgconfig
export CPPFLAGS=-I"${PREFIX}"/include
export LDFLAGS=-L"${PREFIX}"/lib

QEMU_SOURCE_URL="https://download.qemu.org/qemu-7.1.0.tar.xz"


## Install following build time dependencies from brew:
## automake, autoconf, libtool, cmake, meson, ninja, wget, pkg-config

source build.sh

function build_qemu_deps() {
    build_lib_gettext "$1"
    build_lib_libffi "$1"
    build_lib_pcre "$1"
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
    case "$(uname -m)" in
         "x86_64")
             qemu_target="x86_64-softmmu"
             ;;
         "arm64")
             qemu_target="aarch64-softmmu"
             ;;
         *)
             echo "Unknown arch, exiting"
             exit 1
             ;;
    esac

    pushd "${source_dir}"
    export PATH=${PREFIX}/bin:${PATH}
    ./configure --disable-bsd-user --disable-guest-agent --disable-curses --disable-libssh --disable-gnutls --enable-slirp=system \
        --enable-vde --enable-virtfs --disable-sdl --enable-cocoa --disable-curses --disable-gtk --disable-zstd --enable-gcrypt \
        --prefix="${PREFIX}" --target-list="${qemu_target}"

    make V=1 install
}

if build_qemu; then
    popd
    tar -C "${PREFIX}" -cJf qemu-macos-"${CPU}".tar.xz .
fi

