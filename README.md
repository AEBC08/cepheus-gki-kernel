# cepheus GKI Kernel

为 **Xiaomi Mi 9（codename `cepheus`，SoC SM8150 / Snapdragon 855）** 移植 **GKI 2.0 内核**，目标是支撑一类原生 ROM（最终目标 Infinity X / Android 17）在这台原生 4.14 非 GKI 的机器上长期运行。

> 本仓库是**项目控制仓库**（决策记录、路线、风险、脚本），**不含内核源码**。内核源码树在 `src/`（已被 `.gitignore` 忽略），来源与基线见 `memory/decisions/D002-baseline-sources.md`。

## 当前阶段

**S0 — 基线盘点与决策落地**（详见 `docs/roadmap.md`）

| 项 | 状态 |
|---|---|
| 目标内核版本 | 已定：ACK `android12-5.10`（Linux 5.10 LTS，GKI 2.0） |
| 源码基线 | 已定：ACK(GitHub mirror) + CAF `msm-5.10` techpack + 继承 cepheus DTS |
| 模块化 / KMI 策略 | 已定：GKI 形态但不做 Google KMI 认证 |
| 构建环境 | 已定：GitHub Actions 为主 + 本机 WSL2 为辅（D004/D006）。本机无法原生构建，且大 pack 拉取不稳定 → 一律走 CI |
| 流水线 | 已就位：`scripts/fetch-sources.sh`、`scripts/build-kernel.sh`、两个 workflow（语法/`--check`/YAML 均已校验，尚未在真实 CI 跑通） |
| 仓库/提交规范 | 已定：见 `memory/decisions/D005-repo-and-conventions.md` |

## 关键事实速览

- 原厂内核：**4.14（非 GKI）**；当前社区树（crDroid 17.0 / Evolution X bka / Lineage 23.2）仍全部停留在 **4.14.357**，说明 Android 17 用户空间**不依赖** GKI 才能启动——本项目的动机是寿命与可维护性，不是"能否开机"。
- Android 17 的 AOSP GKI 基线是 **`android17-6.18`**（6.18 LTS）。6.18 在 cepheus 上不现实（闭源 HAL 与内核 ABI 强耦合），故取 5.10 作为**可闭环的最优 GKI 基线**。
- 已有重要前置成果：`qaz6750/android_kernel_xiaomi_sm8150`（`android-5.4.y`，Linux 5.4.302）已把 SM8150 + cepheus DTS 前移到 5.4（ACK android11-5.4 + CAF LAHAINA msm-5.4 techpack），且作者已实机启动 HyperOS 2 并跑通指纹/面容。本项目以它为**跳板**而非终点。

## 目录结构

```
.
├─ README.md                 本文件：项目目标与状态
├─ docs/
│  ├─ roadmap.md             里程碑 S0–S3 与验收标准
│  ├─ risk-register.md       风险登记册（含缓解措施）
│  └─ conventions.md         代码/提交/分支规范
├─ memory/                   决策与发现记录（**每次会话必读、必更新**）
│  ├─ README.md              记忆库约定与模板
│  ├─ STATE.md               当前状态快照
│  ├─ OPEN.md                待决问题
│  ├─ decisions/             Dnnn-*.md（ADR）
│  └─ findings/              Fnnn-*.md（调研结论）
└─ src/                      内核源码工作区（不入库）
```

## 约束与原则

1. **每次决策必须落文件**，写入 `memory/decisions/`，编号不复用。
2. **不做破坏性操作**：不 force-push、不覆盖未提交改动、不删除他人分支。
3. **可回退**：任何阶段都必须保留"刷回 4.14 boot.img 即可恢复"的能力。
4. **代码规范**：内核代码遵循 Linux 内核风格并通过 `checkpatch.pl --strict`（例外需在提交信息中说明）；提交信息格式见 `docs/conventions.md`。
