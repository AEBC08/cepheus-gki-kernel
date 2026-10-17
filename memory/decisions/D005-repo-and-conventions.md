# D005 — 仓库布局、分支策略与提交规范

- **状态**：已定
- **日期**：2026-10-17
- **决策者**：PI-Desktop（提案）

## 背景

项目同时涉及：ACK 底板、CAF techpack、cepheus 机型 DTS、以及跨多个社区仓库的 cherry-pick。若不先固定布局与规范，后续会出现"改了什么、为什么改、能不能回退"都无法追溯的情况，也与用户"记录每一次决策 + 代码要规范"的要求冲突。

## 决策

### 1. 仓库拆分

| 仓库 | 内容 | 备注 |
|---|---|---|
| **本项目控制仓库**（当前目录） | `memory/`、`docs/`、`scripts/`、CI 配置 | 只放决策、文档、脚本，**不放内核源码** |
| **内核工作树** `src/kernel/` | 单个内核树（ACK 5.10 底板 + in-tree techpack + cepheus DTS） | 单独 git 仓库，已被 `.gitignore` 排除 |

**为什么单树而非多仓库**：CAF 官方做法也是把 techpack 放进内核树（`techpack/*`），跨仓库的 Makefile 依赖极难维护；单树还能让一次构建对应一个 commit，天然可复现。

### 2. 分支与合并策略

- 内核工作树分支：
  - `ack-5.10`：纯 ACK 底板镜像（只从 `ack` remote fast-forward/merge，**不提交自有改动**）
  - `cepheus-5.10`：我们的工作分支（从 `ack-5.10` 起，承载 techpack 导入 + DTS 移植 + 机型改动）
- remote：`ack` = ACK 镜像源（`aosp-mirror/kernel_common`），`caf` = 各 techpack 源（`git.codelinaro.org`）。
- **禁止**把 4.14 社区树设为 remote 并整树 merge（见 D002）。
- 发版打 tag：`cepheus-5.10-YYYYMMDD[-rcN]`；tag 必须指向"能构建出已实机验证过的产物"的 commit（未验证的 commit 不打 tag）。
- **禁止 force-push** 到 `cepheus-5.10` 与任何已发布 tag。

### 3. 提交信息规范

格式（对齐内核社区习惯）：

```
<subsystem>: <短句祈使式摘要>

<为什么必须改：问题现象 / 根因 / 约束>

<怎么改：关键实现选择，必要时说明为何不用显而易见的替代方案>

<验证方式：如何证明改对了，例如"实机启动，dmesg 无 XXX 报错">

Signed-off-by: <name> <email>
```

- 摘要不超过 72 字符，不以句号结尾；`subsystem` 用内核惯用前缀（`arm64: dts:`、`techpack: display:`、`clk: qcom:` …）。
- 移植自其它树/上游的提交必须标注来源方式：`UPSTREAM:` / `BACKPORT:` / `FROMGIT:` / `CHERRY-PICK`，并写明原 commit、原仓库、分支与原始作者（保留原作者 `Signed-off-by`/`Author`）。
- **一个提交只做一件事**：禁止把"驱动修改 + DTS 修改 + defconfig 修改"混在一个提交里。
- 每个提交必须可构建（不允许提交"中间态编不过"的代码到 `cepheus-5.10`）。

### 4. 代码规范

- 内核 C 代码遵循内核 `Documentation/process/coding-style.rst`；提交前跑 `scripts/checkpatch.pl --strict`，**warning 必须清零或说明理由**。
- 不改动上游/CAF 代码的既有风格（不做无关的格式化，避免 diff 噪声）。
- 机型新增文件命名遵循既有约定：DTS 放 `arch/arm64/boot/dts/xiaomi/`，配置片段放 `arch/arm64/configs/vendor/`。
- 脚本用 `bash` + `set -euo pipefail`，变量加引号，路径不硬编码（用环境变量 + 默认值）。
- 本控制仓库的 Markdown：一文件一主题，禁止把调研原始输出整段贴入（放 `memory/findings/` 并摘要）。

### 5. 目录与文件规则

- `.gitignore` 必须排除：内核源码 `src/`、构建产物 `out/`、`*.o`、`*.ko`、`Image*`、`*.dtb`、`*.dtbo`、工具链压缩包。
- 决策编号 `Dnnn`、发现编号 `Fnnn`、问题编号 `Qnnn` 全局唯一且不复用（见 `memory/README.md`）。

## 理由

- **判断**：单树 + 双分支（`ack-5.10` / `cepheus-5.10`）能让"上游更新"与"我们的改动"界限清晰，`git rebase`/`merge` 都能随时判断冲突归属。
- **已验证**：5.4 前移树也是单树 + in-tree techpack 的组织方式，说明该结构在 SM8150 上可行。

## 影响与后续

- S1 首个脚本必须强制校验：当前分支、HEAD commit、toolchain 版本，并把三者写入产物元数据（`build-info.txt`），用于"产物 ↔ 源码"可追溯。
- 复核触发：若 techpack 需要频繁跟随 CAF 更新，再考虑改成 `git subtree`（保留 subtree 前缀以便 `git subtree pull`）。
