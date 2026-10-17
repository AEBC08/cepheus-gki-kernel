# F007 — `kernel-build` run #6 成功：首个 arm64 `Image` 产出

- **日期**：2026-10-18
- **方法**：Actions API（run/jobs/steps/artifacts）+ 下载 artifact 校验 + 下载 run 日志核对 config 断言。以下均为**已验证事实**。

## 1. 结果

| 项 | 值 |
|---|---|
| run | `kernel-build` #6，id `39060300452`，commit `614b46b` |
| 结论 | ✅ **success**（所有 16 个步骤绿） |
| job 总耗时 | 18:56:42 → 19:16:16 = **19 分 34 秒** |
| 构建步骤耗时 | 18:57:52 → 19:16:05 = **18 分 13 秒** |
| artifact | `kernel-cepheus-5.10-6`，15.85 MB |

对比：run #5（fragment 无效、仍做 full LTO + KASAN）跑了 65 分钟仍未完成并导致 runner 失联。

## 2. 产物内容（已下载核对）

```
build-info.txt    657 bytes
Image          29,901,312 bytes  (28.5 MiB)
System.map      6,205,585 bytes
```

**`Image` 是合法的 arm64 内核镜像**（已验证）：
- offset 56 起 4 字节 = `ARMd`（即 `ARM\x64` magic）
- 起始 4 字节 = `4D 5A 00 91`，即合法的 arm64 分支指令

**`build-info.txt` 关键字段**：

```
kernel_head  = 9360e0b02a7f1595661f6a087ef4c439594475a7
kernel_branch= android12-5.10
dirty_files  = 0
defconfig    = gki_defconfig
fragments    = config/bringup-lite.config
config_sha256= dc5fb83e37a5d017819ee26c9647d6af1d67bb97b2fe343bf1dd62584d3b953b
toolchain    = Ubuntu clang version 14.0.0-1ubuntu1.1
make_command = make -C .../src/kernel -j4 ARCH=arm64 O=.../out LLVM=1 LLVM_IAS=1 \
               CROSS_COMPILE=aarch64-linux-gnu- CC=ccache clang Image
```

## 3. bring-up 配置确实生效（日志断言）

构建后 `grep out/.config` 的输出：

```
CONFIG_LTO_NONE=y
# CONFIG_LTO_CLANG_FULL is not set
# CONFIG_CFI_CLANG is not set
# CONFIG_KASAN is not set
# CONFIG_DEBUG_INFO is not set
```

merge_config 期间出现 4 条 "Previous value / New value" 警告——因为旧 fragment 的注释行里写了 `CONFIG_xxx=y` 形式，被 merge_config 当成上一个符号的值一起吞掉。功能上是正确结果（`LTO_NONE=y`），但噪声大且脆弱，已在提交里把注释里所有 `CONFIG_xxx=y` 去掉。

## 4. 环境数据（来自构建前资源快照步骤）

```
vCPU = 4
Mem  = 15987 MB total, 14511 MB available
磁盘 = 146G 总量，构建前 39G 已用 / 107G 可用
源码 = 1.3G (src/kernel)
```

→ **1.3 GB** 是 ACK 树的真实体积，与 379 MB 快照（含 `.git`）不矛盾；排除 `.git` 后快照应显著变小（下一次 bootstrap 会打印 `du -sh`、源文件数、快照条目数以便核对）。

## 5. 本次踩到的两个小问题（已修）

1. **`.config` 未进 artifact**：`actions/upload-artifact` 默认**不上传隐藏文件**（v4.4+ 的 `include-hidden-files: false`）。已在 `scripts/build-kernel.sh` 里额外把配置复制成 `kernel.config`。
2. **fragment 注释噪声**：见第 3 节。

## 6. 结论

**S1 第 2 步验收通过**：ACK `android12-5.10` 在 CI 上、以 `gki_defconfig` + bring-up 片段、用 clang 14 交叉编译，稳定产出可用的 arm64 `Image`，单次约 18 分钟。

下一步可以进入 cepheus 机型适配（DTS 移植 + `cepheus.config`），不再需要动工具链。
