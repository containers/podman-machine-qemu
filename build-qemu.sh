#!/bin/bash

set -exu

PREFIX=${PREFIX:-/tmp/qemu-test-build}

! [ -d "${PREFIX}" ] && mkdir -p "${PREFIX}"

export LIBRARY_PATH="${PREFIX}"/lib
export CPATH="${PREFIX}"/include
export PKG_CONFIG_PATH="${LIBRARY_PATH}"/pkgconfig
export CPPFLAGS=-I"${PREFIX}"/include
export LDFLAGS=-L"${PREFIX}"/lib

QEMU_SOURCE_URL="https://download.qemu.org/qemu-6.2.0.tar.xz"

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

    # Backport the following commits from QEMU master (QEMU 7):
    # - ad99f64f hvf: arm: Use macros for sysreg shift/masking
    # - 7f6c295c hvf: arm: Handle unknown ID registers as RES0
    #
    # These patches are required for running the following guests:
    # - Linux 5.17
    # - Ubuntu 21.10, kernel 5.13.0-35.40  (March 2022)
    # - Ubuntu 20.04, kernel 5.4.0-103.117 (March 2022)
    #
    # See https://gitlab.com/qemu-project/qemu/-/issues/899
    wget -q --content-disposition -O hvf_1.diff "https://gitlab.com/qemu-project/qemu/-/commit/ad99f64f1cfff7c5e7af0e697523d9b7e45423b6.diff"
    wget -q --content-disposition -O hvf_2.diff "https://gitlab.com/qemu-project/qemu/-/commit/7f6c295cdfeaa229c360cac9a36e4e595aa902ae.diff"
    patch -s -p1 < hvf_1.diff
    patch -s -p1 < hvf_2.diff

    ./configure --disable-bsd-user --disable-guest-agent --disable-curses --disable-libssh --disable-gnutls --enable-slirp=system \
        --enable-vde --disable-virtfs --disable-sdl --enable-cocoa --disable-curses --disable-gtk --prefix="${PREFIX}" \
        --target-list=aarch64-softmmu
    
    make V=1 install
    popd
}


if build_qemu; then
    tar -C "${PREFIX}" -cJf qemu-macos-"${CPU}" .
fi