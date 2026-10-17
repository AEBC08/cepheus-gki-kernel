# D009 — 修正 bring-up 配置：真正的 LTO 关闭方式 + 关闭 KASAN/CFI/DEBUG_INFO

- **状态**：已定（取代 D008 中"关 LTO"的具体做法）
- **日期**：2026-10-18
- **决策者**：PI-Desktop（基于 run #5 失败与 Kconfig 实测）

## 背景

### 事实 1：run #5 并非编译错误，而是 runner 失联（已验证）

`kernel-build` run #5（commit `4499f8b`）job 记录：

| 项 | 值 |
|---|---|
| 构建步骤开始 | 17:46:27 UTC |
| job 结束 | 18:51:45 UTC（构建阶段持续约 **65 分钟**，无结论） |
| 失败注释（check-run annotation） | `The hosted runner lost communication with the server. Anything in your workflow that terminates the runner process, starves it for CPU/Memory, or blocks its network access can cause this error.` |
| 该 run 日志 | 下载得到 **22 字节空包**（runner 死亡导致日志未上传） |

即：不是编译报错，是 runner 被资源耗尽/失去联系。

### 事实 2：D008 里"关 LTO"的写法是**无效的**（已验证）

`arch/arm64/configs/gki_defconfig`（ACK android12-5.10）实际内容：

```
CONFIG_LTO_CLANG_FULL=y
CONFIG_CFI_CLANG=y
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_KASAN=y
CONFIG_KASAN_HW_TAGS=y
```

而 `arch/Kconfig` 中 LTO 是一个 **choice**：

```
choice  prompt "Link Time Optimization (LTO)"  default LTO_NONE
config LTO_NONE / config LTO_CLANG_FULL / config LTO_CLANG_THIN
```

`CONFIG_LTO` 与 `CONFIG_LTO_CLANG` 只是被 `select` 的隐藏符号，**不能被 fragment 直接置空**。
D008 的 `config/bringup-no-lto.config` 写的是 `# CONFIG_LTO_CLANG is not set` 与 `# CONFIG_LTO is not set`
→ 对实际 config 毫无作用，run #5 仍然做了 full LTO，而且还额外背着 KASAN + DEBUG_INFO。

**这解释了为什么 run #5 比 run #2 更慢**（65 分钟仍未完成，而 run #2 编译阶段只用了 23 分钟）。

## 决策

1. 用 `config/bringup-lite.config` **取代** `config/bringup-no-lto.config`，内容基于**实测符号名**：
   - `CONFIG_LTO_NONE=y`（choice 的正确写法）+ 显式 `# CONFIG_LTO_CLANG_FULL/THIN is not set`
   - `# CONFIG_CFI_CLANG is not set`
   - `# CONFIG_KASAN is not set`（menuconfig，子选项自动失效）
   - `# CONFIG_DEBUG_INFO is not set` + `# CONFIG_DEBUG_INFO_DWARF4 is not set`
2. 删除旧文件，避免两份配置并存造成混淆。
3. `kernel-build` 的 `device_configs` 默认值改为 `config/bringup-lite.config`。
4. 保持不变的部分：D008 的"缓存键内容寻址"结论与"源码不入 git、走 Release 快照"结论。

## 理由

- **已验证**：符号名与 choice 结构来自核对 ACK 源码（`gki_defconfig`、`arch/Kconfig`、`lib/Kconfig.kasan`），不是猜测。
- **判断（待 run #6 验证）**：去掉 full LTO + KASAN + DWARF4 后，同样 4 vCPU 上全量编译应降到 10–15 分钟量级，runner 不会再因资源耗尽失联。

## 备选方案与否决理由

- **保留 KASAN 只关 LTO**：否决。KASAN 使编译时间与内存成倍上升，bring-up 阶段完全不需要。
- **换更大 runner（如 8 核付费）**：暂不。先证明默认 runner 足够；若仍失败再评估。
- **保留 DEBUG_INFO 以便调试设备首启**：现阶段否决。设备还没开始刷；若后续需要 vmlinux 符号，再单独开一次带 `DEBUG_INFO` 的构建。

## 影响与后续

- **复核触发**：S3 收尾必须移除 `config/bringup-lite.config` 并恢复 GKI 默认（LTO/KASAN/CFI/DEBUG_INFO），否则产物与 GKI 官方形态不一致。
- run #6 若仍在构建阶段失联，则下一步：`JOBS: 2`、并去掉 `out` 缓存（避免每轮 1–2 GB 上传）后复测。
