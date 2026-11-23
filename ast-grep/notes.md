# ast-grep 实测记录

重打包自上游 `app-<arch>-apple-darwin.zip`（不重编译）。2026-11-23。

| 架构 | 归档 | 大小 | sha256 |
| --- | --- | --- | --- |
| arm64 | `ast-grep-0.51.3-arm64.tar.xz` | 5,541,608 B | `5ea2e6054853a5fed24a8054c9fae64642558ce1c41695dfc7d5ecf27bba2fd6` |
| amd64 | `ast-grep-0.51.3-amd64.tar.xz` | 6,165,824 B | `84558e50bb01bca7e937ecbfb3b1410d0c4e84cc17706c2eb5165c9c2d52ecee` |

上游 zip 的 sha256：arm64 `7954eab1e280…30b1`、amd64 `af04ed50…3acd`。

## 布局

```
bin/ast-grep   （主命令）
bin/sg         （上游保留的旧名，启动时会打印 deprecation 提示）
```

注意：上游 0.51 起把 `sg` 标成 deprecated，但仍随包发布。安装时两个都会链到 `links/`。
