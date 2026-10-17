# D010 — 内核改动以 overlay + patches 形式承载（内核树不入 git）

- **状态**：已定
- **日期**：2026-10-18
- **决策者**：PI-Desktop

## 背景

项目当前形态：本控制仓库只有决策/文档/脚本；内核树由 `scripts/fetch-sources.sh` 在 CI 拉取到 `src/kernel`（不版本化，D008/D009）。

这带来一个立即的阻塞：**我们自己的内核改动（cepheus DTS、机型 config、驱动补丁）无处存放**。改了 `src/kernel` 里的文件，既不会进 git，下一轮缓存/拉取也会被覆盖。

可选方案：

1. 把完整内核树提交进本仓库 —— 已被 D008 否决（1.2 GB、网络无法维护）。
2. 另建一个 ACK fork 仓库并推送我们的提交 —— 本机网络连 200 MB pack 都推不上去，不可行。
3. **改动留在本仓库，以 overlay（新文件）+ patch（修改现有文件）的形式，构建前应用到拉下来的树上**。
4. 只在 CI 里手工改 —— 不可复现，否决。

## 决策

采用方案 3，具体约定：

### 目录

```
kernel/
├─ overlay/      按内核树相对路径放置"新增文件"（原样复制进 src/kernel）
└─ patches/      *.patch，按文件名排序依次 git apply（用于修改 ACK 既有文件）
```

### `scripts/prepare-kernel.sh` 的行为（幂等）

1. 校验 `src/kernel` 存在；
2. `git reset --hard` + `git clean -fdx` —— 把树恢复为 fetch 后的干净状态（因此重复执行结果一致，也不会把上次的 overlay 残留带进来）；
3. `rsync -a`（无则回退 `cp -a`）复制 `kernel/overlay/` 覆盖到树内；
4. 依次 `git apply` `kernel/patches/*.patch`，任一失败即中止并打印出错补丁名；
5. 输出摘要（复制文件数 / 应用补丁数 / 内核 HEAD），并写入 `src/kernel/.cepheus-prep` 供 `build-info.txt` 引用。

### 约束

- `overlay/` 只放**新增**文件；**修改** ACK 既有文件一律走 `patches/`（避免整文件覆盖导致上游更新时丢失改动）。
- patch 必须 `git apply` 干净可用；提交前在工作区本地验证（无法本地编译，但 `git apply --check` 可在 CI 前置步骤做）。
- 每个 patch 一个逻辑改动，文件名带序号与主题：`0001-arm64-dts-add-cepheus-machine-dts.patch`。

## 理由

- **已验证**：本机无法推大仓库（多次失败），内核 fork 路线不可行。
- **已验证**：`src/kernel` 在 CI 中通过缓存还原（键 `src-ack-<pin>-v1`），因此"每次 prep 前 reset"成本极低（git 元数据操作，秒级）。
- **判断**：overlay/patch 分离能让"我们改了什么"在 `git log` 里一目了然，也便于将来整体迁到真正的内核 fork（只需把这些 patch 一次 `git am` 过去）。

## 备选方案与否决理由

- **全部用 patches（含新增文件）**：可行但笨重——新增 40 多个 dtsi 用 patch 表达可读性差；overlay 更适合新文件。
- **`git subtree` 把内核塞进本仓库**：仓库体积等同于方案 1，否决。
- **把 `out/`+`src/` 一起打进 Release 当"开发快照"**：无法表达增量，否决。

## 影响与后续

- `docs/roadmap.md` 的 S1 工作项改为"在 `kernel/overlay` 与 `kernel/patches` 中产出改动"。
- `build-info.txt` 增加 overlay/patch 摘要，保证"产物 ↔ 改动"可追溯。
- 复核触发：若某天能稳定推送大仓库，可把这些 patch 一次性 `git am` 到真正的内核 fork，overlay 内容直接提交，然后废弃本机制。
