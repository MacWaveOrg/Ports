# MacWaveOrg/Ports

给 MacWave 用的**自建产物**：上游不发 macOS 二进制时，我们自己编译，把
「怎么编的」与编出来的东西一起留在这里。

它替掉的是「产物散落在个人账户」的做法。产物仍然由 `MacWaveOrg/Bottle` 提供下载
（客户端的地址是拼出来的，见下），本仓库负责**溯源**：谁编的、用什么参数编的、
哪个上游提交、以及原始产物本身。

## 为什么下载仍然走 Bottle

客户端的默认取件地址是

```
<MACWAVE_BOTTLE_DOMAIN>/<包名>/<文件名>
默认 = https://github.com/MacWaveOrg/Bottle/releases/download
```

它不是读索引记录里的 `url` —— `url` 只在 `--install-from-source` 时才会被用到。
所以每个自建包要放**两份**：

| 放哪 | 放什么 | 谁读 |
| --- | --- | --- |
| 本仓库的 Release（tag = 包名） | 原始产物 + 构建脚本附件 | 人、审计、`--install-from-source` |
| `MacWaveOrg/Bottle` 的 Release（tag = 包名） | 同样两个架构的产物，文件名按 `<包名>@<版本>.<架构>` | 客户端、镜像同步 |

索引记录里 `url` 指向**本仓库**的 Release，`file` 写上游/原始文件名。

## 目录

```
<包名>/
    README.md      这个包为什么自建、上游从哪一版起不发 macOS 产物
    build.sh       可复现的构建脚本（固定上游 tag、固定 configure 参数）
    notes.md       实测记录：架构、min_os、otool -L 的输出、跑过的命令

scripts/
    fetch.sh            统一取件口（见下）
    relocate_stage.sh   打包前的重定位
    selfbuilt_check.sh  上传前的闸门
```

## 取件一律走 `scripts/fetch.sh`

国内网络（校园网、家宽）常年把 `github.com` 本身掐掉，而 `api.github.com` /
`codeload.github.com` 通常还是通的 —— 实测同一条链路 `github.com` 12 秒连不上，
`api.github.com` 0.3 秒 200。所以 build.sh 里不要直接写 `curl`：

```bash
bash "$FETCH" "<url>" "<output>"
```

- `github.com/<owner>/<repo>/releases/download/<tag>/<file>` → 走 `gh release download`
  （打 API，再重定向到 CDN，完全不碰 `github.com`）；`gh` 不可用时退回 curl。
- 其他（kernel.org、codeload、上游自有域名）→ curl，带重试。
- 需要 `git clone` 的上游，改成取 `https://codeload.github.com/<owner>/<repo>/tar.gz/...`
  再解包，不要 clone。

取件方式换了不影响可信度：每个 build.sh 都按 sha256 锁死上游产物，下错了直接失败。

## 上传前必跑：`scripts/selfbuilt_check.sh`

每个 `build.sh` 结尾都会说「先跑 `scripts/selfbuilt_check.sh` 再上传」，这个脚本就是
那道闸门。它检查的是**装到用户机器上才会暴露**的问题：

| 检查 | 为什么 |
| --- | --- |
| 架构与 `--arch` 一致 | 拿 arm64 的产物发 amd64 的条目，用户那边直接 `Bad CPU type` |
| `codesign --verify` 通过 | 改过路径没重签，Apple Silicon 上根本不执行 |
| 引用里没有绝对路径 | **4.6 起的硬规则**：除 `/usr/lib`、`/System`、`/Library/Apple`，`LC_LOAD_DYLIB` / `LC_ID_DYLIB` 只能是 `@loader_path` / `@rpath` / `@executable_path`。写死了就只能在构建机那个目录里跑 |
| 整树包的文本文件里没有构建目录 | 例如编进去的 `GIT_EXEC_PATH`，Mach-O 检查看不见，换台机器就指向不存在的目录 |

```bash
bash scripts/selfbuilt_check.sh out/bash-arm64 --arch arm64
bash scripts/selfbuilt_check.sh out/git-2.56.1-arm64.tar.xz --arch arm64 --tree --main bin/git
```

退出码非 0 就不要上传。如果报的是「绝对路径」，说明这个包**必须在构建时重定位**：
用 MacWave 仓库的 `scripts/relocate_rpath.py <stage-dir>` 改成 `@loader_path` 相对形式，
重新签名后再打包（规则与取舍见 MacWave 的 `docs/RELOCATION.md`）。

`git/build.sh` 已经把这步固化了，其余包照它的样子加：

```bash
relocate() {
    python3 "$RELOCATE" "$stage" --check && return 0   # 已经干净就跳过
    python3 "$RELOCATE" "$stage"
    python3 "$RELOCATE" "$stage" --check
}
```

两条约束：

1. **stage 要摆成运行时布局** `<stage>/bin/<名称>@<版本>/`。`relocate_rpath.py` 按
   客户端最终安装的位置算相对路径，布局不同算出来的就是错的（和 MacPorts 的
   `destroot` 一个道理）。
2. **顺序只能是「编 → 重定位 → 签名 → 打包」**。`install_name_tool` 改写 Mach-O 会
   作废已有签名；反过来先签后改，产物在 Apple Silicon 上直接不执行。
   LDFLAGS 里记得带 `-Wl,-headerpad_max_install_names`，否则路径变长会写不下。

## 发布之后：四处清单要一起改

自建包一旦进了 Bottle + 索引，**官网与三份 README 必须同步**，否则「索引里有、
网站上没有」：

| 位置 | 改什么 |
| --- | --- |
| `infosource/README.md` | `Supported Packages` 一节加/改一行 `<包名> by <作者>` |
| `MacWave/README.md`、`README.zh-Hans.md` | 同上，两份逐行相同 |
| `Pages/index.html` | `<div class="pkg-list">` 加一行 `<span>包名</span>`（只有包名） |

发**版本**时还要改官网的版本号（`Pages/i18n.js` 的 `version.block`，8 种语言）——
细则见 `MacWave/docs/RELEASE-CHECKLIST.md` 第 6 步。

## 已收录

| 包 | 上游 | 上游最后一版带 macOS 产物 |
| --- | --- | --- |
| `choma` | [opa334/ChOma](https://github.com/opa334/ChOma) | 从不发布二进制，只能自建 |
| `aria2c` | [aria2/aria2](https://github.com/aria2/aria2) | 1.35.0（2022 年，只有 x86_64；1.36/1.37 只剩 Windows 与源码） |
