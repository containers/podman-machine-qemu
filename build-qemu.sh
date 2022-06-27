#!/bin/bash

set -exu

PREFIX=${PREFIX:-/opt/podman/qemu}

! [ -d "${PREFIX}" ] && mkdir -p "${PREFIX}"

export LIBRARY_PATH="${PREFIX}"/lib
export CPATH="${PREFIX}"/include
export PKG_CONFIG_PATH="${LIBRARY_PATH}"/pkgconfig
export CPPFLAGS=-I"${PREFIX}"/include
export LDFLAGS=-L"${PREFIX}"/lib

QEMU_SOURCE_URL="https://download.qemu.org/qemu-7.0.0.tar.xz"


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
    pushd "${source_dir}"

    ./configure --disable-bsd-user --disable-guest-agent --disable-curses --disable-libssh --disable-gnutls --enable-slirp=system \
        --enable-vde --enable-virtfs --disable-sdl --enable-cocoa --disable-curses --disable-gtk --prefix="${PREFIX}" \
        --target-list=aarch64-softmmu,x86_64-softmmu
    
    make V=1 install
    popd
}


if build_qemu; then
    tar -C "${PREFIX}" -cJf qemu-macos-"${CPU}".tar.xz .
fi
