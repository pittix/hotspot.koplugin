#!/bin/sh
# Builds hostapd.musl: a fully static hostapd for ARMv7 hard-float, linked against musl.
#
# Why: the bundled `hostapd` is static glibc, which refuses to run on kernels older
# than 3.2 ("FATAL: kernel too old"). The Kindle Voyage runs 3.0.35-lab126.
# musl has no such floor.
#
# Recipe adapted from kindshare by unrealJune (https://github.com/unrealJune/kindshare,
# build/Dockerfile and build/hostapd.defconfig; MIT, Copyright (c) 2026 June Philip):
# same hostapd 2.11, libnl 3.7.0, static -Os build and hostapd config.
# Difference: this cross-compiles on the host with Bootlin's armv7-eabihf musl
# toolchain, instead of building natively in an Alpine arm/v7 container under QEMU.
#
# Usage: tools/build-hostapd-musl.sh [output]     (default output: ./hostapd.musl)
# Needs: curl, tar, xz, make, sha256sum, sha512sum, readelf. Everything else is
# downloaded into .tmp/hostapd-musl/ (gitignored; delete it to clean up).
set -eu

HOSTAPD_VER=2.11
LIBNL_VER=3.7.0
TOOLCHAIN=armv7-eabihf--musl--stable-2025.08-1

HOSTAPD_URL=https://w1.fi/releases/hostapd-$HOSTAPD_VER.tar.gz
LIBNL_URL=https://github.com/thom311/libnl/releases/download/libnl$(echo "$LIBNL_VER" | tr . _)/libnl-$LIBNL_VER.tar.gz
TOOLCHAIN_URL=https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/$TOOLCHAIN.tar.xz

# Source checksums from Alpine aports (3.21-stable main/hostapd, 3.18-stable main/libnl3).
HOSTAPD_SHA512=1382af2a243e3a555507b55942f41d1233cc942826d26bc4f4dbe5e75560b3fe22e426948762fe162453e934685a69ef0c05723b7fecef71811fc1987e32b048
LIBNL_SHA512=80fbbc079299c90afd2a5eda62e4d4f98bf4ef23958c3ce5101f4ed4d81d783af733213bb3bab15f218555d8460bc2394898f909f4ac024fc27281faec86a041
# Toolchain checksum from Bootlin's published $TOOLCHAIN.sha256, pinned on 2026-10-31.
# Set TOOLCHAIN_SHA256= (empty) to fetch Bootlin's file instead, e.g. after changing TOOLCHAIN.
TOOLCHAIN_SHA256=${TOOLCHAIN_SHA256-2f3a34458c3a8b961bd09f89669130fcdc4c1dbc6e31ada720527e4ad3741c11}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$ROOT/.tmp/hostapd-musl
OUT=${1:-$ROOT/hostapd.musl}
DL=$WORK/dl
SRC=$WORK/src
SYSROOT=$WORK/sysroot
JOBS=$(nproc 2>/dev/null || echo 2)
mkdir -p "$DL" "$SRC" "$SYSROOT"

fetch() { # url file
    if [ ! -f "$DL/$2" ]; then
        echo ">> downloading $1"
        curl -fL --proto '=https' --tlsv1.2 --retry 3 -o "$DL/$2.part" "$1"
        mv "$DL/$2.part" "$DL/$2"
    fi
}

check() { # algo hash file
    echo "$2  $DL/$3" | "${1}sum" -c - || { echo "!! checksum mismatch for $3" >&2; exit 1; }
}

fetch "$HOSTAPD_URL" "hostapd-$HOSTAPD_VER.tar.gz"
check sha512 "$HOSTAPD_SHA512" "hostapd-$HOSTAPD_VER.tar.gz"
fetch "$LIBNL_URL" "libnl-$LIBNL_VER.tar.gz"
check sha512 "$LIBNL_SHA512" "libnl-$LIBNL_VER.tar.gz"
fetch "$TOOLCHAIN_URL" "$TOOLCHAIN.tar.xz"
if [ -z "$TOOLCHAIN_SHA256" ]; then
    fetch "${TOOLCHAIN_URL%.tar.xz}.sha256" "$TOOLCHAIN.sha256"
    TOOLCHAIN_SHA256=$(cut -d' ' -f1 "$DL/$TOOLCHAIN.sha256")
fi
check sha256 "$TOOLCHAIN_SHA256" "$TOOLCHAIN.tar.xz"

# Toolchain
if [ ! -d "$WORK/$TOOLCHAIN" ]; then
    tar -xJf "$DL/$TOOLCHAIN.tar.xz" -C "$WORK"
fi
CROSS=$(ls "$WORK/$TOOLCHAIN"/bin/*-linux-musleabihf-gcc | head -n1)
CROSS=${CROSS%gcc}
HOST=$(basename "${CROSS%-}")
echo ">> toolchain: $HOST"

# libnl (static, installed into a private sysroot)
rm -rf "$SRC/libnl-$LIBNL_VER"
tar -xzf "$DL/libnl-$LIBNL_VER.tar.gz" -C "$SRC"
(
    cd "$SRC/libnl-$LIBNL_VER"
    ./configure --host="$HOST" --prefix=/usr --libdir=/usr/lib \
        --enable-static --disable-shared --disable-cli --disable-pthreads \
        CC="${CROSS}gcc" AR="${CROSS}ar" RANLIB="${CROSS}ranlib" CFLAGS="-Os"
    make -j"$JOBS"
    make install DESTDIR="$SYSROOT"
)

# hostapd. CFLAGS/LDFLAGS go through the environment: hostapd's Makefile appends
# its include paths to CFLAGS, which a command-line CFLAGS= would override.
rm -rf "$SRC/hostapd-$HOSTAPD_VER"
tar -xzf "$DL/hostapd-$HOSTAPD_VER.tar.gz" -C "$SRC"
cp "$ROOT/tools/hostapd-musl.defconfig" "$SRC/hostapd-$HOSTAPD_VER/hostapd/.config"
(
    cd "$SRC/hostapd-$HOSTAPD_VER/hostapd"
    export CFLAGS="-Os"
    export LDFLAGS="-static -L$SYSROOT/usr/lib"
    make -j"$JOBS" CC="${CROSS}gcc" LIBNL_INC="$SYSROOT/usr/include/libnl3" hostapd
    "${CROSS}strip" hostapd
)

BIN=$SRC/hostapd-$HOSTAPD_VER/hostapd/hostapd
if readelf -d "$BIN" 2>/dev/null | grep -q NEEDED; then
    echo "!! hostapd is dynamically linked" >&2
    exit 1
fi
cp "$BIN" "$OUT"
chmod 755 "$OUT"
echo ">> built $OUT"
file "$OUT" 2>/dev/null || true
sha256sum "$OUT"
