# D008 — bring-up 阶段关闭 full LTO，并修正源码缓存键

- **状态**：已定（其中"关 full LTO 的具体写法"已被 **D009 取代**——原 fragment 用了无效符号；缓存键内容寻址与"源码不入 git、走 Release 快照"两条结论仍然有效）
- **日期**：2026-10-18
- **决策者**：PI-Desktop（提案，用户已同意"先关 LTO"方向）

## 背景

### 事实 1：run #2 不是编译错误，而是 LTO 阶段被中断（已验证，F005）

`kernel-build` run #2（commit `a7a1cf4`）日志时间线：

| 时刻 (UTC) | 事件 |
|---|---|
| 15:41:35 | job 开始 |
| 15:44:24 | 构建开始（首个 `CC init/main.o`） |
| 16:07:53 | **全部对象编译完成**，进入 `LTO vmlinux.o` |
| 16:19:54 | `##[error]The runner has received a shutdown signal` → `make: *** [Makefile:1328: vmlinux] Terminated` |

即：C 代码编译**全程无错**（`CROSS_COMPILE` 修复有效），死在 full LTO 链接。

### 事实 2：缓存键设计有缺陷，导致每轮重复上传约 1GB（已验证）

两个 workflow 的 cache key 都写成 `...-${{ github.run_id }}`。`actions/cache` 的条目是不可变的，带 `run_id` 等于**每轮新建一份**：

- `src-ack-head-<run_id>`：ACK 源码树 + techpack，约 1 GB
- `out-<run_id>`：构建输出，首次完整构建后 1–2 GB

GitHub 仓库缓存配额为 10 GB，几轮之后就会开始驱逐旧条目，并让"每轮都重新下载 + 重新上传"变成常态。这既是浪费，也是不稳定的来源。

## 决策

1. **bring-up 阶段关闭 full LTO**：新增 `config/bringup-no-lto.config`（`# CONFIG_LTO_CLANG is not set`），通过 `DEVICE_CONFIGS` 合并。
   - **有效期**：仅 S1/S2。**S3（模块化收尾）前必须移除**并恢复 LTO，否则产物与 GKI 官方形态不一致。
   - 该文件在仓库中可见，任何一次构建的 `build-info.txt` 都会记录 `fragments`，可追溯。
2. **缓存键改为内容寻址（不含 run_id）**：
   - 源码：`src-ack-${{ vars.ACK_SHA || 'head' }}-v1`
   - ccache：`ccache-v1`（restore-keys `ccache-`）
   - 构建输出：`out-v1`（restore-keys `out-`）
   - 语义：**pin 变化或需要强制重建时，把 `-v1` 递增到 `-v2`**，而不是靠 run_id 制造新条目。
3. **不把内核源码提交进仓库**（回应"能否把源码放项目里"）：见下节。

## 为什么不把源码放进仓库

| 方案 | 稳定性 | 每次构建耗时 | 代价 |
|---|---|---|---|
| **缓存键修正（采用）** | 高（命中即 1–2 分钟还原） | 首次约 2–4 分钟（下载 + 上传），之后仅还原 | 无仓库膨胀 |
| 源码入库（git commit） | 高 | checkout 约 1–2 分钟 | 仓库一次性 +1.2 GB 且**永久留在历史**；GitHub 对 >1 GB 仓库给出警告；他人克隆成本极高 |
| Release 资源 tarball | 中高 | 每次下载约 120 MB | 需维护版本；仍是一次网络下载 |

**决定性理由（已验证）**：本机网络上推 **200 MB 级 pack 连续失败两次**（`curl 18 transfer closed`）。把 1.2 GB 的 ACK 树推送上去，从这台机器基本不可能成功；而修缓存键是 3 行改动，收益等价。→ 因此否决"源码入库"，采用缓存键修正。

> 若将来确实需要"源码快照"作为交付物，走 **Release 资源**（`ack-5.10-<sha>.tar.zst`），不污染 git 历史。

## 影响与后续

- run #3 起构建时间预期从"23 分钟编译 + 30 分钟 LTO"降到约 **20–25 分钟整体**。
- **复核触发**：S3 开始时必须新建决策恢复 LTO；若缓存键 `-v1` 因 pin 变化导致误用旧树，递增版本号。
- 需在 `docs/roadmap.md` 的 S3 验收里补一条"LTO 已恢复"。
