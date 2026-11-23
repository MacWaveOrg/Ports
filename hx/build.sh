#!/bin/bash

# hx/build.sh —— 把上游产物重新打包成 MacWave 的整树布局（**不重新编译**）
#
# 上游：https://github.com/helix-editor/helix
# 上游产物：helix-25.07.1-<arch>-macos.tar.xz（sha256 见 notes.md）
# 输出：hx-25.07.1-<架构>.tar.xz，布局 bin/ + runtime/
#
# 为什么要重打包：整树包（install: "tree"）的约定是「可执行文件在 bin/ 下」，
# 而 上游 tar 里 `hx` 与 `runtime/` 是并列的，`hx` 不在 bin/ 下。
# 二进制字节原样保留（只做移动 + ad-hoc 签名），所以行为与上游产物一致。

set -eE
set -u
set -o pipefail

VERSION="25.07.1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$PWD/out}"

GREEN='\033[32m'
RED_BOLD='\033[1;31m'
RESET='\033[0m'
say() { printf '%b\n' "$*"; }
die() { printf '%b\n' "${RED_BOLD}🌊 Error: $*${RESET}" >&2; exit 1; }

for tool in curl clang codesign tar shasum; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool not found"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hx-repack.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

build_one() {
    local arch="$1" url="$2" sha="$3"
    local dir="$WORK/tree-$arch"
    local stage="$dir/stage"

    say "${GREEN}🌊 Repacking ${arch}${RESET}"
    mkdir -p "$dir/extract" "$stage/bin"
    local archive="$WORK/$(basename "$url")"
    curl -fsSL -o "$archive" "$url"
    echo "$sha  $archive" | shasum -a 256 -c - >/dev/null \
        || die "upstream $arch artifact does not match the pinned sha256"
    case "$archive" in
        *.zip) unzip -qo "$archive" -d "$dir/extract" ;;
        *.tar.gz) tar -xzf "$archive" -C "$dir/extract" ;;
        *.tar.xz) tar -xJf "$archive" -C "$dir/extract" ;;
    esac

    local root="$dir/extract"
    local entries=("$root"/*)
    if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" ]]; then
        root="${entries[0]}"
    fi

    mv "$root/hx" "$stage/bin/"
    mv "$root/runtime" "$stage/"
    if [[ -f "$root/LICENSE" ]]; then cp "$root/LICENSE" "$stage/"; fi


    while IFS= read -r file; do
        file "$file" | grep -q Mach-O && codesign --force --sign - "$file" >/dev/null 2>&1
    done < <(find "$stage" -type f)

    mkdir -p "$OUT"
    tar -cJf "$OUT/hx-${VERSION}-${arch}.tar.xz" -C "$stage" .
}

build_one arm64 "https://github.com/helix-editor/helix/releases/download/25.07.1/helix-25.07.1-aarch64-macos.tar.xz" "00b1651b4fdbbe0a2ae981c8e76b858bd26a7c33f5b3583f3b6bb9137d54f1ff"
build_one amd64 "https://github.com/helix-editor/helix/releases/download/25.07.1/helix-25.07.1-x86_64-macos.tar.xz" "84dc32d617d28d32f4aa21e3aafac47bd715d1154aeb977697d4d60b887b7103"

say ""
say "${GREEN}🌊 Artifacts in ${OUT}${RESET}"
for arch in arm64 amd64; do
    f="$OUT/hx-${VERSION}-${arch}.tar.xz"
    printf '  %-34s %10s B  %s\n' "$(basename "$f")" "$(stat -f%z "$f")" \
        "$(shasum -a 256 "$f" | cut -d' ' -f1)"
done
say ""
say "下一步：解包后 bash scripts/selfbuilt_check.sh x/bin/hx --arch arm64 --bin-name hx"
say "        索引记录写 install: \"tree\" 与 min_client_version: \"4.5.0\"。"
