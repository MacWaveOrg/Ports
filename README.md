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
```

## 已收录

| 包 | 上游 | 上游最后一版带 macOS 产物 |
| --- | --- | --- |
| `choma` | [opa334/ChOma](https://github.com/opa334/ChOma) | 从不发布二进制，只能自建 |
