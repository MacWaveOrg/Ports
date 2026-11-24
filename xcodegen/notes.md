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

## 2026-11-24 重建（4.6 重定位）

`stage` 改为运行时布局 `bin/<名称>@<版本>/`，打包前跑 `scripts/relocate_stage.sh`，
顺序为「编 → 重定位 → 签名 → 打包」。上面的哈希表已过期，以索引为准：

```
fb6ce56d7542c4d59b20de0dcfcdd7bf0a0d0edc90cfff67037157d72c4a3c2d  arm64  (min_os 14.0)
211156aebc3b0e624eff1a3547e9f0caff99df94c7283b8241e22afe450f06dd  amd64  (min_os 14.0)
```

### 预设全找不到：`share/xcodegen` 少了一层（2026-11-24 修）

`build.sh` 原来写 `cp -R SettingPresets "$pkg/share/xcodegen"`，`share/xcodegen`
不存在时 `cp -R` 会把**内容**铺到该名下，于是得到 `share/xcodegen/Configs`；
而代码按 `bundlePath + "../share/xcodegen/SettingPresets/<path>.yml"` 找
（`SettingsBuilder.swift`），一层都对不上。

后果很隐蔽：**工程照生成，`xcodegen --version` 也照常通过**，只是 `base` /
`config` / `platform` 三类默认构建设置是空的，日志里只有三行
`No "debug config" settings found`。

修法：装到 `share/xcodegen/SettingPresets/`。验证方式不是看退出码，而是生成一个
最小工程后 `grep -c 'ENABLE_STRICT_OBJC_MSGSEND\|CLANG_ENABLE_OBJC_ARC'`，
修之前是 0，修之后是 4。
