# kernel/patches/ — 修改 ACK 既有文件的补丁

## 规则（决策见 `memory/decisions/D010-kernel-change-carrying.md`）

1. 文件名：`000N-<subsystem>-<topic>.patch`，**按文件名排序应用**。
   例：`0001-arm64-dts-hook-xiaomi-dir-into-makefile.patch`
2. 必须是 `git apply` 可直接应用的格式（`git format-patch` 或 `git diff` 均可）。
   提交前先自查：`bash scripts/prepare-kernel.sh --check`
3. 一个补丁一个逻辑改动，可单独 revert。
4. 补丁头保留内核提交规范：`<subsystem>: <summary>` + 动机 + `Signed-off-by`。
   移植自其它树的，标注 `CHERRY-PICK from <repo>@<branch> <sha>` 与原作者。

## 为什么不用 overlay 覆盖

覆盖整个 `arch/arm64/boot/dts/Makefile` 之类的大文件，会在上游更新时把新内容整体冲掉，
且 diff 里看不出我们到底加了哪一行。patch 能精确保留意图。
