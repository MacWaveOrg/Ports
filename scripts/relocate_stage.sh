#!/bin/bash

# relocate_stage.sh —— 打包之前，把 stage 树里的绝对引用改成 @loader_path/...
#
# 用法：bash scripts/relocate_stage.sh <stage-root>
#
# <stage-root> 必须是**运行时布局**：
#
#     <stage-root>/bin/<名称>@<版本>/...          软件包自己那一棵
#     <stage-root>/deps/<名>/<名>@<版本>/...      依赖（如果有）
#
# 相对路径是按这个布局算出来的，摆法与客户端最终安装的位置不一致，算出来的就是错的
# （和 MacPorts 的 destroot 一个道理）。
#
# 顺序要求：编 → 本脚本 → 签名 → 打包。`install_name_tool` 改写 Mach-O 会作废已有
# 签名，先签后改，产物在 Apple Silicon 上直接不执行；签名前还要留出改写空间
# （LDFLAGS 带 `-Wl,-headerpad_max_install_names`）。
#
# 本来就干净（只链系统库）就直接返回，不做无谓改写 —— 这一步是闸门，不是固定动作。
#
# 判定与改写的实现只有一份：MacWave 仓库的 scripts/relocate_rpath.py。
# 换位置用 MACWAVE_RELOCATE 指过去。

set -u
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELOCATE="${MACWAVE_RELOCATE:-$(cd "$HERE/../../MacWave" 2>/dev/null && pwd || true)/scripts/relocate_rpath.py}"

GREEN='\033[32m'
RED_BOLD='\033[1;31m'
RESET='\033[0m'
say() { printf '%b\n' "$*"; }
die() { printf '%b\n' "${RED_BOLD}🌊 Error: $*${RESET}" >&2; exit 1; }

STAGE="${1:-}"
[ -n "$STAGE" ] || die "usage: relocate_stage.sh <stage-root>"
[ -d "$STAGE" ] || die "stage directory not found: $STAGE"
[ -f "$RELOCATE" ] || die "relocate_rpath.py not found: $RELOCATE (set MACWAVE_RELOCATE)"
command -v python3 >/dev/null 2>&1 || die "python3 not found"

say "${GREEN}🌊 Checking position independence${RESET}"
if python3 "$RELOCATE" "$STAGE" --check; then
    exit 0
fi

say "${GREEN}🌊 Relocating absolute references${RESET}"
python3 "$RELOCATE" "$STAGE" \
    || die "relocation failed; a reference does not resolve inside the staging tree"
python3 "$RELOCATE" "$STAGE" --check \
    || die "still not position-independent after relocation"
