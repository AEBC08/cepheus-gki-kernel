# D004 — 构建环境（待定，当前阻塞项）

- **状态**：已定（2026-10-17 用户选择"GitHub Actions 为主 + 本机 WSL2 为辅"；落地细节见 D006）
- **日期**：2026-10-17
- **决策者**：用户（待选）

## 背景

Android 内核**不能在 Windows 原生构建**：需要 Linux 用户态（GNU make、bash、perl、python、大小写敏感文件系统、symlink、ELF 工具链），以及 AOSP 预编译 clang。

本机实测数据（F003，已验证）：

| 项 | 实测值 |
|---|---|
| OS | Windows 11 IoT 企业版 LTSC，build 26300 |
| CPU | Intel Core i5-2430M（Sandy Bridge，2 核 4 线程，2.4 GHz） |
| 内存 | 7.9 GB |
| 磁盘可用 | C: 54.6 GB，D: 128.9 GB，E: 94.7 GB |
| WSL | **未安装**（`wsl -l -v` 返回安装提示） |
| Docker | **不可用** |
| 工具链 | git ✓、python 3.13 ✓、bash(Git) ✓；**clang / make / adb / fastboot 全部缺失** |

估算（判断）：内核全量编译在 2C4T 上约 60–90 分钟/次（`-j4`），且 8 GB 内存对 `CONFIG_LTO_CLANG` 有 OOM 风险（需关 LTO 或加 swap）。

## 候选方案

### 方案 A：本机装 WSL2 + Ubuntu 22.04

- 优点：完全本地、无外部依赖、源码不用上传；调试 `dmesg`/脚本最方便。
- 缺点：需 BIOS 开 VT-x（Sandy Bridge 支持，但需确认）+ 8 GB 内存下 WSL 与 Windows 争抢；编译慢（60–90 分钟/次）；`.wslconfig` 需要限内存约 6 GB 并关 LTO。
- 风险：老旧平台 + Win11 上 WSL2 的稳定性；若 VT-x 不可用则直接失败。

### 方案 B：GitHub Actions（推荐）

- 优点：`ubuntu-latest` 4C/16 GB，构建约 20–35 分钟；产物用 artifact 回传；仓库公开即免费；天生可复现（workflow 即构建脚本）。
- 缺点：需要把源码/构建仓库推到 GitHub（Q007）；单次 6 小时超时上限（内核构建远低于此）；无法直接对真机做 adb 操作（产物下载到本机再刷）；公开仓库等于开源。
- 备注：可配合 `ccache`/`actions/cache` 二次构建显著加速。

### 方案 C：云主机（按需）

- 优点：可自定义（如 8C/16 GB），能做完整 AOSP ROM 构建。
- 缺点：成本；需要用户提供账号与凭据。

## 决策

**已定：方案 B（GitHub Actions）为主 + 方案 A（本机 WSL2）为辅。** CI 负责可复现的全量构建与产物归档，WSL2 负责将来小改动快速验证与本地脚本调试。

补充说明（2026-10-17 复核）：
- 本机网络**无法完成 kernel tree 拉取**（两次 `RPC failed`，见 F003 补充），因此首次"编出东西"完全依赖 CI，WSL2 暂不安装、不阻塞 S1。
- 具体 runner 版本、工具链、缓存与产物元数据策略见 D006。

## 影响与后续

选定后必须补：
1. 把本记录状态改为"已定"，并写清具体基础镜像/runner 版本、clang 版本、构建命令。
2. 产出 `scripts/` 下的构建脚本，**在对应环境中实测通过后才算完成**（不接受"未验证脚本"入库为最终态）。
3. 沉淀工具链版本（clang `rXXX`、`LLVM=1`、`LLVM_IAS=1`）到 `docs/`，保证可复现。
