# choma 实测记录

数值取自 2026-11-21 迁移时的核对（对个人账户时代的产物逐字节比对，见 README）。

## 产物

| 架构 | lipo -archs | 大小 | min_os | sha256 |
| --- | --- | --- | --- | --- |
| arm64 | arm64 | 134,296 B | 11.0 | `090031020461775f3ff818681e838ca44c7ab535925b605e6bafca6da70abbf8` |
| amd64 | x86_64 | 116,408 B | 11.0 | `4e4b2e94ff42109f53c403facfcbaecc55cd2313135fe25a26e47bad220762d6` |

## 索引记录

`infosource/pkg/pkginfo_<架构>/choma/_choma@1.0-macwaveteam2`：

```
sha256: "<上表>"
file: "ChOma_<架构>"      ← 裸可执行文件，没有扩展名，所以 payload_filename 拼出
                            choma@1.0-macwaveteam2.<架构>
url: "https://github.com/MacWaveOrg/Ports/releases/download/choma/ChOma_<架构>"
min_os: "11.0"
```

## 当时跑过的验证

```
$ ./choma 2>&1 | head -2        # 打印用法，退出码 0
$ otool -L choma                # 只有 /usr/lib/*，没有第三方 dylib
```

（库链接是静态进可执行文件的，所以 `otool -L` 干净。）
