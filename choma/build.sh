#!/bin/bash

# choma/build.sh —— 可复现地编出 choma 的两个架构
#
# 上游：https://github.com/opa334/ChOma
# 产物：裸可执行文件（不带扩展名），文件名 ChOma_<架构>
#
# 三条约束，别改：
#   1. 固定上游 tag，不要跟 main —— 索引里的 sha256 对应的是某一次具体构建；
#   2. 两个架构分别编，不要出 universal：MacWave 的索引是「每架构一个产物」；
#   3. 编完 ad-hoc 签名（Apple 芯片对未签名的 arm64 直接拒绝执行）。
#
# 用法：bash choma/build.sh <上游 tag> [输出目录]
# 依赖：Xcode 命令行工具、openssl（pkg-config libcrypto）、make

set -eE
set -u
set -o pipefail

RED_BOLD='\033[1;31m'
GREEN='\033[32m'
RESET='\033[0m'

TAG="${1:-v1.0-macwaveteam2}"
OUT="${2:-$PWD/out}"

say() { printf '%b\n' "$*"; }
die() { printf '%b\n' "${RED_BOLD}🌊 $*${RESET}" >&2; exit 1; }

for tool in git make clang lipo codesign vtool; do
    command -v "$tool" >/dev/null || die "缺少 $tool（Xcode 命令行工具：xcode-select --install）"
done
command -v pkg-config >/dev/null || die "缺少 pkg-config（brew install pkg-config）"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "🌊 取上游 $TAG"
git clone --quiet --depth 1 --branch "$TAG" https://github.com/opa334/ChOma "$WORK/ChOma"

mkdir -p "$OUT"

for arch in arm64 amd64; do
    triplet=$([[ "$arch" == arm64 ]] && echo arm64 || echo x86_64)
    say "🌊 编译 $arch（clang -arch $triplet）"
    make -C "$WORK/ChOma" clean >/dev/null 2>&1 || true
    make -C "$WORK/ChOma" \
        CFLAGS="-arch $triplet -Wall -Werror $(pkg-config --cflags libcrypto) -fPIC \
                -Wno-pointer-to-int-cast -Wno-unused-command-line-argument \
                -Wno-deprecated-declarations -framework CoreFoundation \
                -mmacosx-version-min=10.13" \
        LDFLAGS="-arch $triplet" \
        DISABLE_SIGNING=0 DISABLE_TESTS=1 >/dev/null

    built="$(find "$WORK/ChOma/output" -maxdepth 2 -type f -perm -111 | head -1)"
    [[ -n "$built" ]] || die "$arch 编完没找到可执行文件"

    cp "$built" "$OUT/ChOma_$arch"
    chmod +x "$OUT/ChOma_$arch"
    codesign --force --sign - "$OUT/ChOma_$arch" 2>/dev/null \
        || die "$arch ad-hoc 签名失败"
done

say ""
for arch in arm64 amd64; do
    f="$OUT/ChOma_$arch"
    say "  $(lipo -archs "$f")  $(basename "$f")  $(wc -c < "$f" | tr -d ' ') B"
    say "    min_os $(vtool -show-build "$f" 2>/dev/null | awk '/minos/{print $2; exit}')"
    say "    sha256 $(shasum -a 256 "$f" | awk '{print $1}')"
done
say ""
say "${GREEN}🌊 产物在 $OUT —— 先跑 scripts/selfbuilt_check.sh 再上传${RESET}"
