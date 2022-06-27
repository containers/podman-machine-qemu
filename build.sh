#!/bin/bash

set -exu

LIBGETTEXT_URL="https://ftpmirror.gnu.org/gettext/gettext-0.21.tar.gz"
LIBFFI_URL="https://github.com/libffi/libffi/releases/download/v3.4.2/libffi-3.4.2.tar.gz"
LIBPCRE_URL="https://www.mirrorservice.org/sites/ftp.exim.org/pub/pcre/pcre-8.45.tar.bz2"
LIBGLIB_URL="https://download.gnome.org/sources/glib/2.72/glib-2.72.2.tar.xz"
#CA_CERTIFICATE_URL="https://curl.se/ca/cacert-2022-04-26.pem"
LIBGMP_URL="https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz"
LIBNETTLE_URL="https://ftpmirror.gnu.org/nettle/nettle-3.7.3.tar.gz"
#LIBGNUTLS_URL="https://www.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/gnutls/v3.7/gnutls-3.7.4.tar.xz"
LIBIDN2_URL="https://ftpmirror.gnu.org/libidn/libidn2-2.3.2.tar.gz"
LIBUNISTRING_URL="https://ftpmirror.gnu.org/libunistring/libunistring-1.0.tar.gz"
LIBZSTD_URL="http://fresh-center.net/linux/misc/zstd-1.5.2.tar.gz"
LIBJPEG_URL="https://fossies.org/linux/misc/jpegsrc.v9e.tar.gz"
LIBPNG_URL="https://github.com/anjannath/mirror/releases/download/0.0.1/libpng-1.6.37.tar.xz"
LIBSLIRP_URL="https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.7.0/libslirp-v4.7.0.tar.gz"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v1.0.26/libusb-1.0.26.tar.bz2"
LIBLZO_URL="https://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz"
LIBPIXMAN_URL="https://cairographics.org/releases/pixman-0.40.0.tar.gz"
LIBSNAPPY_URL="https://github.com/google/snappy/archive/1.1.9.tar.gz"
LIBVDE2_URL="https://github.com/anjannath/mirror/releases/download/0.0.1/vde2-2.3.2.tar"
#LIBOPENSSL11_URL="http://www.mirrorservice.org/sites/ftp.openssl.org/source/openssl-1.1.1o.tar.gz"

function download_and_extract() {
    local tarball ext_dir
    
    tarball=$(basename "$1")
    if ! [ -f "${tarball}" ]; then
        wget -q --content-disposition "$1"
    fi
    
    ext_dir="$(tar -tf "${tarball}" | head -1 | tr -d '/')"
    if ! [ -d "${ext_dir}" ]; then
        tar -xf "${tarball}"
    fi

    echo "${ext_dir}"
}

NCORES=$(sysctl -n hw.ncpu)

case "$(uname -m)" in
    "x86_64")
        CPU="amd64"
        ;;
    "arm64")
        CPU="aarch64"
        ;;
    *)
        echo "Unknown arch, exiting"
        exit 1
        ;;
esac

KERNEL_VERSION=$(uname -r)
KERNEL_BUILD_FLAG="${CPU}-apple-darwin${KERNEL_VERSION%%.*}" # aarch64-apple-darwin21

# the following are depenedencies of glib
function build_lib_gettext() {
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/gettext.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBGETTEXT_URL}")
    pushd "${source_dir}" || exit
    ./configure --disable-dependency-tracking \
        --disable-silent-rules --disable-debug \
        --prefix="$1" --with-included-glib \
        --with-included-libcroco --with-included-libunistring \
        --with-included-libxml --with-emacs \
        --with-lispdir="$1/share/emacs/site-lisp/gettext" \
        --disable-java --disable-csharp --without-git --without-cvs \
        --without-xz --with-included-gettext
    make -j "${NCORES}"
    make install
    popd || exit
}

function build_lib_libffi() {
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/libffi.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBFFI_URL}")
    pushd "${source_dir}" || exit
    ./configure --disable-debug --disable-dependency-tracking --prefix="$1" --libdir="$1/lib"
    #make install
    popd || exit
}

function build_lib_pcre() {
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/pcre.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBPCRE_URL}")
    pushd "${source_dir}" || exit
    # TODO: apply patch as in homebrew
    ./configure --disable-dependency-tracking --enable-utf8 \
        --enable-pcre8 --enable-pcre16 --enable-pcre32 --enable-unicode-properties \
        --enable-pcregrep-libz --enable-pcregrep-libbz2 --prefix="$1"
        
    make -j "${NCORES}"
    make test -j "${NCORES}"
    make install
    popd || exit
}

function build_lib_glib() {
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/glib.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBGLIB_URL}")
    pushd "${source_dir}" || exit
        mkdir build
        pushd build || exit
            meson --prefix="$1" --libdir="$1"/lib --buildtype=release \
                --wrap-mode=nofallback --default-library=both --localstatedir=/var \
                -Diconv=auto -Dgio_module_dir="$1"/lib/gio/modules -Dbsymbolic_functions=false -Ddtrace=false ..
            ninja -v
            ninja install -v
            # need to rewrite some python #! inside /tmp/anjan/libs/bin/(file *)
        popd || true
    popd || exit
}

# # the following are dependencies of gnutls
# function build_ca-certificates() {
#     # https://github.com/Homebrew/homebrew-core/blob/master/Formula/ca-certificates.rb
#     wget -q -c "${CA_CERTIFICATE_URL}"
#     CACERT_PATH=$(readlink -f "$(basename "${CA_CERTIFICATE_URL}")")
#     readonly CACERT_PATH
# }

# gmp is also directly used by qemu
function build_lib_gmp() {
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/gmp.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBGMP_URL}")
    pushd "${source_dir}" || exit
    ./configure --prefix="$1" --libdir="$1"/lib --enable-cxx --with-pic --build="${KERNEL_BUILD_FLAG}"
    make -j "${NCORES}"
    make check -j "${NCORES}"
    make install
    popd || exit
}

function build_lib_unistring() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/libunistring.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBUNISTRING_URL}")
    pushd "${source_dir}" || exit
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix="$1"
    make -j "${NCORES}"
    make check -j "${NCORES}"
    make install
    popd || exit
}

function build_lib_libidn2() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/libidn2.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBIDN2_URL}")
    pushd "${source_dir}" || exit
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix="$1" # --with-libintl-prefix="$1"
    make install
    popd || exit
}

function build_lib_zstd() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/zstd.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBZSTD_URL}")
    pushd "${source_dir}" || exit
    cmake -S build/cmake -B builddir -DZSTD_PROGRAMS_LINK_SHARED=ON -DZSTD_BUILD_CONTRIB=ON \
        -DCMAKE_INSTALL_RPATH="$1" -DZSTD_LEGACY_SUPPORT=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX="$1" \
        -DCMAKE_INSTALL_LIBDIR="$1"/lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev -DBUILD_TESTING=OFF
    
    cmake --build builddir
    cmake --install builddir
    popd || exit
}

# function build_lib_libtasn1() {

# }

# function build_lib_brotli() {

# }

# nettle is also directly used by qemu
function build_lib_nettle() {
    # https://github.com/Homebrew/homebrew-core/blob/master/Formula/nettle.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBNETTLE_URL}")
    pushd "${source_dir}" || exit
    ./configure --build="${KERNEL_BUILD_FLAG}" --disable-dependency-tracking --prefix="$1" --enable-shared
    make -j "${NCORES}"
    make install
    # some checks are failing
    # make check -j "${NCORES}"
    popd || exit
}

# function build_p11-kit() {

# }

# function build_unbound() {

# }

# function build_lib_gnutls() {
#     # https://github.com/Homebrew/homebrew-core/blob/master/Formula/gnutls.rb
#     local source_dir
#     source_dir=$(download_and_extract "${LIBGNUTLS_URL}")
#     pushd "${source_dir}" || exit
#     # bug in upstream look at the brew formulae for details
#     sed -i '' 's/AM_CCASFLAGS = -Wa,-march=all//1' lib/accelerated/aarch64/Makefile.in
#     CC=clang ./configure --disable-dependency-tracking --disable-silent-rules --prefix="$1" \
#         --sysconfdir="$1"/etc --with-default-trust-store-file="${CACERT_PATH}" --disable-heartbeat-support \
#         --without-p11-kit --with-included-unistring --with-included-libtasn1
#     make install
#     popd || exit
# }

# following are exclusive direct dependencies of qemu
function build_lib_jpeg() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/jpeg.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBJPEG_URL}")
    pushd "${source_dir}" || exit
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix="$1"
    make install
    popd || exit
}

function build_lib_libpng() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/libpng.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBPNG_URL}")
    pushd "${source_dir}"
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix="$1"
    make -j "${NCORES}"
    make test -j "${NCORES}"
    make install
    popd
}

function build_lib_libslirp() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/libslirp.rb
    local source_dir 
    source_dir=$(download_and_extract "${LIBSLIRP_URL}")
    pushd "${source_dir}"
    meson build -Ddefault_library=both --prefix="$1" --libdir="$1"/lib --buildtype=release --wrap-mode=nofallback
    ninja -C build install all
    popd
}

# function build_lib_openssl() {
#     # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/openssl@1.1.rb
#     local source_dir 
#     source_dir=$(download_and_extract "${LIBOPENSSL11_URL}")
#     pushd "${source_dir}"
#     local cpu_arch
#     cpu_arch=$(uname -m)
#     perl ./Configure --prefix="$1" --openssldir="$1"/etc/openssl@1.1 no-ssl3 no-ssl3-method no-zlib \
#         darwin64-"${cpu_arch}"-cc enable-ec_nistp_64_gcc_128

#     make -j "${NCORES}"
#     make install MANDIR="$1"/man MANSUFFIX=ssl
# }

# function build_lib_libssh() {

# }

function build_lib_libusb() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/libusb.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBUSB_URL}")
    pushd "${source_dir}"
    ./configure --disable-dependency-tracking --prefix="$1"
    make install
    popd
}

function build_lib_lzo() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/lzo.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBLZO_URL}")
    pushd "${source_dir}"
    ./configure --disable-dependency-tracking --prefix="$1" --enable-shared
    make -j "${NCORES}"
    make check -j "${NCORES}"
    make install
    popd
}

# function build_lib_ncurses() {

# }

function build_lib_pixman() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/pixman.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBPIXMAN_URL}")
    pushd "${source_dir}"
    ./configure --disable-dependency-tracking --disable-gtk --disable-silent-rules --prefix="$1"
    make install
    popd
}

function build_lib_snappy() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/snappy.rb
    # uses different name for the archive then the name of resource in the URL
    local tarball source_dir
    tarball=snappy-$(basename "${LIBSNAPPY_URL}")
    if ! [ -f "${tarball}" ]; then
        wget -q --content-disposition "${LIBSNAPPY_URL}"
    fi
    source_dir="$(tar -tf "${tarball}" | head -1 | tr -d '/')"
    if ! [ -d "${source_dir}" ]; then
        tar -xf "${tarball}"
    fi

    pushd "${source_dir}"
    cmake . -DCMAKE_INSTALL_NAME_DIR="$1"/lib -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX="$1" -DCMAKE_INSTALL_LIBDIR="$1"/lib -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev
    
    make install
    popd
}

function build_lib_vde2() {
    # https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/vde.rb
    local source_dir
    source_dir=$(download_and_extract "${LIBVDE2_URL}")
    pushd "${source_dir}"
    ./configure --prefix="$1" --disable-python
    make install
    popd
}
