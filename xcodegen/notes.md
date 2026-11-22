# xcodegen 实测记录

数值取自 2026-11-22 的构建（Swift 6.1.2 / Xcode 17 / SDK 15.5，本机 arm64 + Rosetta 跑 amd64）。

## 产物

| 架构 | 归档 | 大小 | `bin/xcodegen` sha256 | min_os |
| --- | --- | --- | --- | --- |
| arm64 | `xcodegen-2.48.0-arm64.tar.xz` | 1,844,204 B | `467a8fd1e667bd5db129b16de9fa1bef59bf494effa6d6f0788cdc7990f3eaf1` | 14.0 |
| amd64 | `xcodegen-2.48.0-x86_64.tar.xz` | 2,079,704 B | `a2a64233ca60dbe2af6b55e1062ab757bcada55b29b45cde486f4669074aaeb7` | 14.0 |

归档本身的 sha256（索引记录里写这两个）：

```
7fc02a8a112b9fce85580ad1e0cbb70d84684d737bb3369196ab504dc1efb290  xcodegen-2.48.0-arm64.tar.xz
8791231078b40808f5b8868e44f0efc4729d85af8f08151cd5869ede6f73335c  xcodegen-2.48.0-x86_64.tar.xz
```

## 只有 2.48.0 这一版

2.47.0 / 2.46.0 只有官方 zip，而官方 zip 经软链启动会丢预设（见 README）。不再提供。

## selfbuilt_check.sh

两个架构都是「除系统库外没有外部依赖」+「实跑 `xcodegen --version` 通过」，
`min_os 14.0` 来自 `Package.swift` 的 `platforms: [.macOS(.v14)]`。

## 功能验证（不只是 --version）

装进沙箱（`install: "tree"`）后用 `links/xcodegen` 生成一个最小工程，与直接运行
`bin/xcodegen` 的结果逐字节比对：

```
$ diff direct.pbxproj link.pbxproj
（无差异）
```

未打补丁的官方产物在同一比对里差 125 行（缺 base/config/platform 默认设置）。
