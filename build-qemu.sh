#!/bin/bash

set -exu

PREFIX=${PREFIX:-/Applications/podman/qemu}

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

    # The following patches add 9p support to darwin.  They can
    # be deleted when qemu-7 is released.
    wget -q -O 9p_1.diff "https://gitlab.com/qemu-project/qemu/-/commit/e0bd743bb2dd4985791d4de880446bdbb4e04fed.diff"
    wget -q -O 9p_2.diff "https://raw.githubusercontent.com/baude/homebrew-qemu/798fdd7c6e2924591f45b282b3f59cb6e9850504/add_9p-util-linux.diff"
    wget -q -O 9p_3.diff "https://raw.githubusercontent.com/baude/homebrew-qemu/798fdd7c6e2924591f45b282b3f59cb6e9850504/remove_9p-util.diff"
    wget -q -O 9p_4.diff "https://raw.githubusercontent.com/ashley-cui/homebrew-podman/e1162ec457bd46ed84aef9a0aa41e80787121088/change.patch"
    wget -q -O 9p_5.diff "https://gitlab.com/qemu-project/qemu/-/commit/f41db099c71151291c269bf48ad006de9cbd9ca6.diff"
    wget -q -O 9p_6.diff "https://gitlab.com/qemu-project/qemu/-/commit/6b3b279bd670c6a2fa23c9049820c814f0e2c846.diff"
    wget -q -O 9p_7.diff "https://gitlab.com/qemu-project/qemu/-/commit/67a71e3b71a2834d028031a92e76eb9444e423c6.diff"
    wget -q -O 9p_8.diff "https://gitlab.com/qemu-project/qemu/-/commit/38d7fd68b0c8775b5253ab84367419621aa032e6.diff"
    wget -q -O 9p_9.diff "https://gitlab.com/qemu-project/qemu/-/commit/57b3910bc3513ab515296692daafd1c546f3c115.diff"
    wget -q -O 9p_10.diff "https://gitlab.com/qemu-project/qemu/-/commit/b5989326f558faedd2511f29459112cced2ca8f5.diff"
    wget -q -O 9p_11.diff "https://gitlab.com/qemu-project/qemu/-/commit/029ed1bd9defa33a80bb40cdcd003699299af8db.diff"
    wget -q -O 9p_12.diff "https://gitlab.com/qemu-project/qemu/-/commit/d3671fd972cd185a6923433aa4802f54d8b62112.diff"
    wget -q -O 9p_13.diff "https://raw.githubusercontent.com/NixOS/nixpkgs/8fc669a1dd84ae0db237fdb30e84c9f47e0e9436/pkgs/applications/virtualization/qemu/allow-virtfs-on-darwin.patch"

    for i in {1..13}; do
        patch -s -p1 < 9p_"$i".diff
    done


    ./configure --disable-bsd-user --disable-guest-agent --disable-curses --disable-libssh --disable-gnutls --enable-slirp=system \
        --enable-vde --enable-virtfs --disable-sdl --enable-cocoa --disable-curses --disable-gtk --prefix="${PREFIX}" \
        --target-list=aarch64-softmmu,x86_64-softmmu
    
    make V=1 install
    popd
}


if build_qemu; then
    tar -C "${PREFIX}" -cJf qemu-macos-"${CPU}".tar.xz .
fi
