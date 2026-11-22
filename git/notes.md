# git 实测记录

数值取自 2026-11-22 的构建（macOS Xcode 17 / SDK 15.5，本机 arm64 + Rosetta 跑 amd64）。

## 产物

| 架构 | 归档 | 大小 | `bin/git` sha256 | min_os |
| --- | --- | --- | --- | --- |
| arm64 | `git-2.56.1-arm64.tar.xz` | 7,078,180 B | `ffa9629af71affdb6b6514cd5f4f5b2ac3121636806207a624bfb23a99cd38b9` | 12.0 |
| amd64 | `git-2.56.1-amd64.tar.xz` | 7,800,808 B | `f53773d624bc050d51a20af467e26e05a8b7925184e3cc3333fcc8fab256326f` | 12.0 |

归档本身的 sha256（索引记录里写这两个）：

```
2ff8bdc17568b97d9b3ab087ae55d2ae643932b1b64eb81ed5df99f367d77773  git-2.56.1-arm64.tar.xz
ecf8a4d90ee2c50e6fa52098ff9381dbc75bc5d592592dae3fb0ff00a2db3ad0  git-2.56.1-amd64.tar.xz
```

注意 `bin/git` 的 sha256 与归档的不同：索引要写**归档**的哈希（客户端校验的是下载到的那个文件）。

## selfbuilt_check.sh

```
✅ Mach-O（magic cffaedfe）
✅ 架构 arm64（索引里的 arm64）
✅ 可执行位在
✅ ad-hoc 签名有效
✅ min_os 12.0（LC_BUILD_VERSION）
✅ 除系统库外没有外部依赖（静态链接干净）
✅ 实跑 git --version 通过（exit 0）
```

amd64 走 Rosetta 跑同样全绿。

## 实测过的命令

沙箱装了一次（`install: "tree"` → `bin/git@2.56.1/` 整棵 + `links/git@2.56.1`），然后：

```
$ links/git@2.56.1 --version
git version 2.56.1
$ links/git@2.56.1 --exec-path
/tmp/mwgit/bin/git@2.56.1/libexec/git-core      ← 指向安装目录，不是构建目录
$ links/git@2.56.1 clone --depth 1 https://github.com/octocat/Hello-World.git /tmp/c
$ links/git@2.56.1 -C /tmp/c log --oneline -1
7fd1a60 Merge pull request #6 from Spaceghost/patch-1
```

## 踩过的坑

1. **`-arch amd64` 不存在。** clang 只认 `x86_64`；索引里叫 amd64 是 MacWave 的命名。
2. **默认会链 `clang` 是 MacPorts 的。** 本机 PATH 里 `/opt/local/bin` 排在前面，
   直接用 `clang` 编出来的 `otool -L` 是 `/opt/local/lib/libz.1.dylib`。必须写
   `/usr/bin/clang`，并加 `NO_DARWIN_PORTS` / `NO_HOMEBREW`（git 的 Makefile 会
   主动把 `/opt/local/include`、`/opt/local/lib` 加进搜索路径）。
3. **默认编 Rust 组件。** `varint.c` 只在 `NO_RUST` 时进 `LIB_OBJS`，否则符号由
   Rust 静态库提供；交叉编 x86_64 时那部分没编出来，链接报
   `_encode_varint` 未定义。加 `NO_RUST=YesPlease`。
4. **`RUNTIME_PREFIX` 在软链下失效。** 见 README 的补丁一节；不补的话
   `--exec-path` 指向构建机的 `/Users/…/stage-arm64/libexec/git-core`。
