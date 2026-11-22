#!/bin/bash

# xcodegen/build.sh —— 编出 XcodeGen 的两个架构产物（整树：bin/ + share/）
#
# 上游其实发布 macOS 产物（xcodegen.zip），但那版**经软链启动时会找不到预设**：
# 它用 Bundle.main.bundlePath（= _NSGetExecutablePath 给的软链路径）去拼
# "../share/xcodegen/SettingPresets"，MacWave 把包装进 bin/xcodegen@<版本>/、
# 再软链 links/xcodegen 过去，于是这句落到 links/../share 上，生成的工程会静默
# 缺少 base/config/platform 的默认构建设置（实测少 125 行）。
#
# presets-symlink.patch 多加两个候选路径：把 bundlePath 先 resolvingSymlinksInPath()
# 再拼。除此之外没有任何改动，也不要改 —— 官方 zip 与这里的差别只有这一个补丁。
#
# 用法：bash xcodegen/build.sh [输出目录]
# 依赖：Xcode（swift 命令）、codesign、tar

set -eE
set -u
set -o pipefail

VERSION="2.48.0"
SRC_URL="https://github.com/yonaskolb/XcodeGen.git"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$PWD/out}"

GREEN='\033[32m'
RED_BOLD='\033[1;31m'
RESET='\033[0m'

say() { printf '%b\n' "$*"; }
die() { printf '%b\n' "${RED_BOLD}🌊 Error: $*${RESET}" >&2; exit 1; }

for tool in git swift codesign tar; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool not found (install Xcode)"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/xcodegen-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

say "${GREEN}🌊 Fetching XcodeGen ${VERSION}${RESET}"
git clone --depth 1 --branch "$VERSION" "$SRC_URL" "$WORK/src" >/dev/null 2>&1 \
    || die "cannot clone $SRC_URL at $VERSION"
patch -d "$WORK/src" -p1 < "$HERE/presets-symlink.patch"

# 上游 Package.swift 声明 platforms: [.macOS(.v14)]，所以产物本身就是 min_os 14.0，
# 与官方 zip 一致，不要试图往低版本拉。
build_one() {
    local arch="$1"
    local stage="$WORK/stage-$arch"

    say "${GREEN}🌊 Building ${arch}${RESET}"
    (
        cd "$WORK/src"
        rm -rf .build
        # SwiftPM 在本机若把 git 的 safe.bareRepository 设成了 explicit 会直接失败，
        # 这里只在子进程环境里放开，不动用户的全局配置。
        GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all \
            swift build -c release --product xcodegen --arch "$arch"
    )

    mkdir -p "$stage/bin" "$stage/share"
    cp "$WORK/src/.build/$arch-apple-macosx/release/xcodegen" "$stage/bin/"
    cp -R "$WORK/src/SettingPresets" "$stage/share/xcodegen"
    cp "$WORK/src/LICENSE" "$stage/" 2>/dev/null || true
    codesign --force --sign - "$stage/bin/xcodegen" >/dev/null 2>&1

    mkdir -p "$OUT"
    tar -cJf "$OUT/xcodegen-${VERSION}-${arch}.tar.xz" -C "$stage" bin share LICENSE
}

build_one arm64
build_one x86_64

say ""
say "${GREEN}🌊 Artifacts${RESET}"
for arch in arm64 x86_64; do
    file="$OUT/xcodegen-${VERSION}-${arch}.tar.xz"
    printf '  %-40s %10s B  %s\n' "$(basename "$file")" "$(stat -f%z "$file")" \
        "$(shasum -a 256 "$file" | cut -d' ' -f1)"
done
say ""
say "下一步：解包后 bash scripts/selfbuilt_check.sh dist/bin/xcodegen --arch arm64 --bin-name xcodegen"
say "        索引记录写 install: \"tree\" 与 min_client_version: \"4.5.0\"。"
