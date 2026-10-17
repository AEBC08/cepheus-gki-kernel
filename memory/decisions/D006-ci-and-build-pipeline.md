# D006 — 源码获取与构建流水线（CI 为主）

- **状态**：已定
- **日期**：2026-10-17
- **决策者**：用户选定"GitHub Actions 为主 + 本机 WSL2 为辅"（Q001）；流水线细节由 PI-Desktop 提案

## 背景

1. **Q001 已决**：GitHub Actions 负责全量可复现构建与产物归档，本机 WSL2 只做小改快验（D004 的默认建议被采纳）。
2. **本机网络承载力不足**（本轮新增实测，见 F003 补充）：
   - `git clone --depth 1 --branch android12-5.10 https://github.com/aosp-mirror/kernel_common` 两次失败：`RPC failed; curl 18 transfer closed`（69.9 s 与 1418 s 各一次）。
   - 同网络下 `git clone --filter=blob:none --no-checkout`（仅 trees，约几十 MB）此前成功；约 200 MB 的单一 pack 稳定失败。
   - 期间 GitHub 还出现过 504。
   → **结论：本地不做 kernel tree 的 bulk 拉取**，改为在 CI runner 上完成（runner 网络与磁盘都远优于本机）。
3. **CAF 分支命名尚未完全确认**：`display-drivers` 的 5.10 分支可查（`display-kernel.lnx.5.10.r8-rel`、`...5.10.2.r1-rel` 等）；`audio-kernel` / `camera-kernel` / `video-driver` 用 `search=5.10 / lahaina / kona / wapio` 均未得到可靠结果（`video-driver` 仅有 `caf_migration/video-kernel.lahaina.*` 旧分支），且 `camera-kernel` 查询曾超时。→ 记录为 R10，S1 在 CI 上重试确认。

## 决策

1. **构建入口 = GitHub Actions**，`ubuntu-22.04` runner（自带 clang 14，与 5.10 世代匹配），单次 timeout 180 分钟。
2. **两个 workflow**（本仓库 `.github/workflows/`，内核仓库建立后随之迁入）：
   - `bootstrap-sources.yml`：拉取 ACK `android12-5.10` + CAF techpack，校验版本与结构，产出**源码 tarball artifact** + `PINS.txt`（各仓库 HEAD SHA）。用于 S1 第 1 步，且避免本地网络问题。
   - `kernel-build.yml`：对已就绪的内核树执行构建，产出 `Image`/`Image.gz`/`dtb*`/`build-info.txt` artifact。
3. **工具链分两级**：
   - **第一级（S1）**：runner 自带 `clang`/`ld.lld`（Ubuntu 22.04 = clang 14），`LLVM=1 LLVM_IAS=1`。目标是"先编出东西"，快速迭代。
   - **第二级（S3 之前）**：切换到 AOSP 预编译 clang（GKI 5.10 对应 `r416183b` 世代），使构建与 GKI 官方一致。切换属**复核触发**，届时新建决策。
4. **配置组织**：`gki_defconfig` 为底板；机型片段通过 `DEVICE_CONFIGS`（逗号分隔的 `.config` 片段）用 `merge_config.sh` 合并，禁止手改 `out/.config`（延续 D003）。
5. **缓存**：`out/` 与 `ccache` 走 `actions/cache`；源码树按 `PINS.txt` 里的 SHA 组合做 cache key，pin 变则失效。
6. **产物必须自带 `build-info.txt`**：包含内核仓 HEAD SHA、各 techpack SHA、`clang --version`、defconfig 与合并后 `.config` 的 sha256、构建时间、执行的完整 make 命令。→ 满足 D005 的"产物 ↔ 源码"可追溯要求。
7. **本地 WSL2 不做首次验证的依赖**：所有"能编出东西"的里程碑以 CI 绿为准；WSL2 仅用于 `bash -n`/脚本调试与将来小范围增量验证。

## 理由

- **已验证**：本机网络无法完成 kernel tree 拉取（两次失败记录）；CI runner 是唯一稳定通道。
- **已验证**：`bash`（Git Bash）在本机可用，足以对脚本做语法级校验；YAML 亦可静态检查。
- **判断（未验证）**：clang 14 足够编译 ACK 5.10 的 `gki_defconfig`；若出现 `-Werror` 类新告警，按"最小编译修复"原则处理并在提交信息中记录，不提前切换到重量级预编译工具链。

## 备选方案与否决理由

- **本机 WSL2 先行构建**：否决为首选。需先装 WSL2（未安装）+ 8 GB 内存 + 2C4T，单次 60–90 分钟，且网络拉取仍会失败。
- **本地 tarball 下载（codeload）替代 clone**：可作为兜底，但同样受 ~200 MB 单流稳定性影响；且失去 git 历史与后续 merge 能力。保留为应急手段，不入主流程。
- **自建 docker 镜像预置工具链**：当前阶段收益不足，先不引入。

## 影响与后续

- 需要用户在 GitHub 建立两个仓库并授权 Actions（Q007）。
- `scripts/fetch-sources.sh`、`scripts/build-kernel.sh` 的**权威版本在本仓库**，CI 调用同一份脚本，避免"两份逻辑漂移"。
- 复核触发：①CAF 分支名确认后，把 `TECH_*_BRANCH` 的默认值改为实测值；②出现 clang 14 无法解决的编译错误时，提前切 AOSP 预编译 clang。
