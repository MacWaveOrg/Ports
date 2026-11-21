#!/bin/bash

# aria2c/build.sh —— 可复现地编出 aria2c 的两个架构
#
# 上游：https://github.com/aria2/aria2
# 产物：裸可执行文件（不带扩展名），文件名 aria2c-<架构>
#
# 三条约束，别改：
#   1. 固定上游 tag（release-1.37.0），不要跟 master —— 索引里的 sha256 对应的是
#      某一次具体构建；
#   2. 两个架构分别编，不要出 universal：MacWave 的索引是「每架构一个产物」；
#   3. 编完 ad-hoc 签名（Apple 芯片对未签名的 arm64 直接拒绝执行）。
#
# 依赖面被刻意砍到只剩系统库（zlib + Security + CoreFoundation）：
#   不引 openssl（--with-appletls 走 Secure Transport）、不引 libxml2 / libcares /
#   libssh2 / libnettle / sqlite3 / libexpat，不引 gettext。少一个依赖就少一条
#   「用户机器上 dyld: Library not loaded」的可能。
#
# 用法：bash aria2c/build.sh [上游 tag] [输出目录]
# 依赖：Xcode 命令行工具（clang、make、codesign、lipo、vtool）

set -eE
set -u
set -o pipefail

TAG="${1:-release-1.37.0}"
OUT="${2:-$PWD/out}"
VERSION="${TAG#release-}"

RED_BOLD='\033[1;31m'
GREEN='\033[32m'
RESET='\033[0m'

say() { printf '%b\n' "$*"; }
die() { printf '%b\n' "${RED_BOLD}🌊 Error: $*${RESET}" >&2; exit 1; }

for tool in git make clang lipo codesign vtool curl; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool not found (install the Xcode command line tools)"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aria2-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

say "${GREEN}🌊 Downloading aria2 ${VERSION}${RESET}"
curl -fsSL -o "$WORK/aria2.tar.gz" \
    "https://github.com/aria2/aria2/releases/download/${TAG}/aria2-${VERSION}.tar.gz"
tar xzf "$WORK/aria2.tar.gz" -C "$WORK"
SRC="$WORK/aria2-${VERSION}"
[ -d "$SRC" ] || die "unpacked directory not found: $SRC"

# 两份产物共用的开关。改这些之前先想清楚：每加一个 --with-* 就多一个
# 用户机器上可能缺失的动态库。
COMMON=(
    --with-appletls --without-gnutls --without-openssl
    --without-libxml2 --without-libcares --without-libssh2
    --without-libnettle --without-sqlite3 --without-libexpat
    --disable-nls
)

build_one() {
    local arch="$1" host="$2" tag="$3"
    local dir="$WORK/build-$arch"

    say "${GREEN}🌊 Building ${arch}${RESET}"
    mkdir -p "$dir"
    (
        cd "$dir"
        # BitTorrent 保留（那是 aria2 的主要用途之一，且不需要外部库）；
        # Metalink 会随 --without-libxml2/--without-libexpat 自动关闭。
        if [ "$arch" = "arm64" ]; then
            "$SRC/configure" --prefix="$dir/prefix" "${COMMON[@]}"
        else
            CC=clang CXX=clang++ \
            CFLAGS="-arch x86_64 -O2" CXXFLAGS="-arch x86_64 -O2" LDFLAGS="-arch x86_64" \
            "$SRC/configure" --host=x86_64-apple-darwin --prefix="$dir/prefix" "${COMMON[@]}"
        fi
        make -j"$(sysctl -n hw.ncpu)"
    )

    mkdir -p "$OUT"
    cp "$dir/src/aria2c" "$OUT/aria2c-$tag"
    codesign --force --sign - "$OUT/aria2c-$tag"
    lipo -archs "$OUT/aria2c-$tag"
}

build_one arm64 native arm64
build_one amd64 x86_64-apple-darwin x86_64

say ""
say "${GREEN}🌊 Artifacts in $OUT${RESET}"
for file in "$OUT/aria2c-arm64" "$OUT/aria2c-x86_64"; do
    printf '  %-24s %10s B  %s\n' "$(basename "$file")" "$(stat -f%z "$file")" \
        "$(shasum -a 256 "$file" | cut -d' ' -f1)"
done
say ""
say "下一步：两个产物都过一遍 scripts/selfbuilt_check.sh（在 MacWave 仓库里），"
say "        --arch arm64 / --arch amd64 --bin-name aria2c。"
