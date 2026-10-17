# F005 — `kernel-build` run #2 分析（编译全过，LTO 阶段被中断）

- **日期**：2026-10-18
- **方法**：Actions REST API 取 run/job/step 状态 + 下载 job 日志（`0_build.txt`，339526 B）逐行分析。以下均为**已验证事实**。

## 1. 结论先行

run #2 **不是编译错误**。所有对象在 23 分钟内编译完成，唯一失败点是 `LTO vmlinux.o` 阶段被 runner shutdown 信号中断。

## 2. 时间线（UTC）

| 时刻 | 事件 |
|---|---|
| 15:41:35 | job 开始（commit `a7a1cf4`） |
| 15:44:24 | 开始编译，首个 `CC init/main.o` |
| ~16:07 | `AR drivers/built-in.a`、`GEN .tmp_symversions.lds` 等收尾 |
| 16:07:53 | `LTO vmlinux.o` 开始 |
| 16:19:54 | `##[error]The runner has received a shutdown signal. This can happen when the runner service is stopped, or a manually started runner is canceled.` |
| 16:19:54 | `Killed` / `make: *** [Makefile:1328: vmlinux] Terminated` / `##[error]The operation was canceled.` |

job 记录的 `updated_at` 为 17:04:40（清理阶段拖尾），实际中断发生在开始后约 38 分钟。

## 3. 步骤状态

| 步骤 | 结果 |
|---|---|
| Checkout / 释放磁盘 / 安装依赖 / 准备 ccache / 恢复 out / 恢复源码树 / 拉取源码 | success |
| 构建 | **cancelled**（不是 failure） |
| 显示产物 / 上传产物 | skipped |

`CROSS_COMPILE` 修复（`a7a1cf4`）**已验证有效**：arm64 内联汇编不再报 `unknown register name 'x0'`。

## 4. 缓存命中情况（关键问题）

日志原文：

```
key: ccache-a7a1cf4e4302ea767fd4a137e167ea8abd5c19f1
restore-keys: ccache-
Cache not found for input keys: ccache-a7a1cf4e..., ccache-
Cache not found for input keys: out-39046164126, out-
```

- ccache、`out` 均为首轮未命中（正常）。
- **问题**：`src-ack-*` 与 `out-*` 的 key 含 `${{ github.run_id }}`，而 `actions/cache` 条目不可变 → 每轮都会新建约 1 GB（源码树）+ 1–2 GB（out）的条目，GitHub 10 GB 配额很快被占满并触发驱逐，形成"每轮重下重传"的恶性循环。→ 已在 D008 改为内容寻址键。

## 5. 时间成本分解（用于后续估算）

| 阶段 | 耗时 |
|---|---|
| 依赖安装 + 缓存还原 + 源码拉取 | 约 3 分钟（首次） |
| 全量编译（4 vCPU，gki_defconfig，LTO 尚未生效） | 约 23 分钟 |
| full LTO 链接 | > 12 分钟仍未完成（被中断） |
| 预期（关闭 LTO 后） | 约 20–25 分钟整体 |

## 6. 待办

- 关 LTO 后重跑，确认能产出 `Image` 并上传 artifact。
- 若关 LTO 后仍被 shutdown，需要排查是否为 runner 侧问题（例如并发/配额），届时改用 `ubuntu-24.04` 或提高 `timeout-minutes` 观察。
