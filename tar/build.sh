#!/bin/bash

# tar/build.sh —— 可复现地编出 GNU tar（单文件产物，两个架构分别编）
#
# 上游：https://savannah.gnu.org/projects/tar/
# 源码：https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz
# 产物：tar-<架构>（裸可执行文件，索引里 file: "tar-<架构>"）

set -eE
set -u
set -o pipefail

VERSION="1.35"
SRC_SHA256="4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16"
SRC_URL="https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$PWD/out}"

GREEN='\033[32m'
RED_BOLD='\033[1;31m'
RESET='\033[0m'

say() { printf '%b\n' "$*"; }
die() { printf '%b\n' "${RED_BOLD}🌊 Error: $*${RESET}" >&2; exit 1; }

for tool in curl clang codesign make shasum; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool not found (install the Xcode command line tools)"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/tar-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

say "${GREEN}🌊 Downloading tar ${VERSION}${RESET}"
curl -fsSL -o "$WORK/src.tar" "$SRC_URL"
echo "${SRC_SHA256}  $WORK/src.tar" | shasum -a 256 -c - >/dev/null \
    || die "source tarball does not match the published sha256"
tar -xf "$WORK/src.tar" -C "$WORK"
SRC="$WORK/tar-${VERSION}"

SDK="$(xcrun --show-sdk-path)"

build_one() {
    local arch="$1" carm="$2"
    local stage="$WORK/stage-$arch"

    say "${GREEN}🌊 Building ${arch}${RESET}"
    rm -rf "$WORK/build-$arch"
    cp -R "$SRC" "$WORK/build-$arch"
    (
        cd "$WORK/build-$arch"
        LIBS=-liconv ./configure --prefix="$stage" --disable-nls \
            CC=/usr/bin/clang \
            CFLAGS="-arch $carm -O2 -mmacosx-version-min=11.0 -isysroot $SDK" \
            LDFLAGS="-arch $carm -O2 -mmacosx-version-min=11.0 -isysroot $SDK"
        make -j"$(sysctl -n hw.ncpu)"
        make install
    )

    codesign --force --sign - "$stage/bin/tar" >/dev/null 2>&1
    mkdir -p "$OUT"
    cp "$stage/bin/tar" "$OUT/tar-$carm"
}

build_one arm64 arm64
build_one amd64 x86_64

say ""
say "${GREEN}🌊 Artifacts in ${OUT}${RESET}"
for arch in arm64 x86_64; do
    file="$OUT/tar-$arch"
    printf '  %-28s %10s B  %s\n' "$(basename "$file")" "$(stat -f%z "$file")" \
        "$(shasum -a 256 "$file" | cut -d' ' -f1)"
done
say ""
say "下一步：bash scripts/selfbuilt_check.sh out/tar-arm64 --arch arm64 --bin-name tar"
