# hx（Helix）实测记录

重打包自上游 `helix-25.07.1-<arch>-macos.tar.xz`（不重编译）。2026-11-23。

| 架构 | 归档 | 大小 | sha256 |
| --- | --- | --- | --- |
| arm64 | `hx-25.07.1-arm64.tar.xz` | 16,719,492 B | `da95616876ea5ff96f15f27cb8f37ab2e6e63ae56f4a69cb3d560ebbc39c47a9` |
| amd64 | `hx-25.07.1-amd64.tar.xz` | 17,800,020 B | `7a986653a2ef0cc050dcd8875442cbcc52dbe5ac1cbd4b7d67fcc6488211e52e` |

上游 tar 的 sha256：arm64 `00b1651b…f1ff`、amd64 `84dc32d6…7103`。

## 布局与 min_os

```
bin/hx
runtime/            ← 语法高亮、grammars（.so）、themes
```

`hx` 本体 min_os 11.0，但 `runtime/grammars/*.so` 是 14.5，索引里按整包最大值写 **14.5**。
hx 通过自身可执行文件位置找 `runtime/`，经 `links/hx` 软链启动正常（实测 `hx --version`）。
