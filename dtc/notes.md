# dtc 实测记录

数值取自 2026-11-22 的构建（Xcode 17 / SDK 15.5，本机 arm64 + Rosetta 跑 amd64）。

## 产物

| 架构 | 归档 | 大小 | sha256 |
| --- | --- | --- | --- |
| arm64 | `dtc-1.7.2-arm64.tar.xz` | 91,204 B | `2ae16f489ae43514997a828d4b0e06b04c471219a0a8c7ec432cb0693824f4b4` |
| amd64 | `dtc-1.7.2-x86_64.tar.xz` | 99,588 B | `a6ff81402a02a7bd26ea1b929c857e8023c2e1a35dfb66d2cba2b48401e8a23d` |

## 依赖面

用 1.7.2 而不是 1.8.x（1.8 的 Makefile 只剩「请用 meson」的壳）。装了 Homebrew 的 libyaml 时，Makefile 的 pkg-config 探测会打开 yaml 支持却不链 yaml.o，所以构建脚本里 `PKG_CONFIG=/usr/bin/false` + 显式 `-DNO_YAML`。

## selfbuilt_check.sh

两个架构都全绿（Mach-O、架构、签名、min_os 11.0、无外部依赖、实跑 `--version`）。
