# F001 — 内核与设备树源码盘点

- **日期**：2026-10-17
- **方法**：GitHub REST API（`/repos`、`/commits?per_page=1`、`/branches`、`/orgs/.../repos`、`/search/repositories`）+ `raw.githubusercontent.com` 读取 `Makefile` 的 `VERSION/PATCHLEVEL/SUBLEVEL` 判定内核版本。以下均为**已验证事实**。

## 1. 内核仓库

| 仓库 | 默认分支 | 内核版本 | 分支最新提交 | 备注 |
|---|---|---|---|---|
| `crdroidandroid/android_kernel_xiaomi_sm8150` | `17.0` | 4.14.357 | 2026-10-11 | 分支含 `17.0`、`17.0-raphael`，**维护最活跃** |
| `Evolution-X-Devices/kernel_xiaomi_cepheus` | `bka` | 4.14.357 | 2026-06-26 | cepheus 专用（提交如 `input: fts_521: Suppress touch event log spam`） |
| `Evolution-X-Devices/kernel_xiaomi_sm8150` | `cnb` | 4.14.356 | 2026-02-22 | 通用 sm8150 |
| `LineageOS/android_kernel_xiaomi_sm8150` | `lineage-23.2` | 4.14.356 | 2025-07-02 | 参照基线最干净 |
| `qaz6750/android_kernel_xiaomi_sm8150` | `android-5.4.y` | **5.4.302** | 2026-09-04 | 唯一 SM8150 5.x 前移树，详见 F002 |

`RisingOS-Revived`：`android_kernel_xiaomi_sm8150`、`kernel_xiaomi_sm8150`、`android_device_xiaomi_cepheus` 均 **404**；按 org 分页全量查询（3 页 × 100）后按 `cepheus|sm8150|xiaomi` 过滤，**结果为空**。→ RisingOS 无公开的该机型内核/设备树。

## 2. 设备树仓库

| 仓库 | 默认分支 | 分支列表 | 最新提交 |
|---|---|---|---|
| `crdroidandroid/android_device_xiaomi_cepheus` | `16.0` | 12.1 / 13.0 / 14.0 / 15.0 / 16.0（**无 17.0**） | 2026-01-02 |
| `Evolution-X-Devices/device_xiaomi_cepheus` | `bka` | bka / bka-old / cnb / udc / vic | 2026-06-13（repo push 2026-06-26） |
| `LineageOS/android_device_xiaomi_cepheus` | `lineage-22.2` | 22.2 / 23.2 等 | 2025-11-17 |

注意：crDroid 内核已有 `17.0` 分支但设备树最高只有 `16.0` → 17.0 的设备树未公开或尚未建仓。

## 3. AOSP GKI 基线（`aosp-mirror/kernel_common`，因 `android.googlesource.com` 不可达）

已验证存在的相关分支：`android14-6.1`、`android15-6.6`、`android16-6.12`、**`android17-6.18`（`Makefile` = 6.18.0-rc6）**。

Google `kernel-lifetimes.xml` 关键数据：4.14/4.19/5.4 标 `<no-releases reason="non-GKI kernel">`；5.10 EOL 2027-07；5.15 EOL 2028-07；6.1 EOL 2029-07；6.6 EOL 2028-07。

## 4. ROM 侧

- `ProjectInfinity-X` org：`official_devices/devices/` 下 **无 `cepheus.json`** → Infinity X 无官方 cepheus 支持（自维护/unofficial）。
- `ProjectInfinity-X/kernel_configs` 是 AOSP `kernel/configs` 的 fork（含 `kernel-lifetimes.xml`、`p/q/r/s/t/u/v/w` 各版本配置），**不含 “x”（Android 17）目录**，仓库最后推送 2025-12-28。

## 5. 结论

1. "以最后提交最近的为主"→ 内核选 **crDroid `17.0`**（4.14.357，2026-10-11）；设备树选 **Evolution X `bka`**（2026-06-26）为最新，但 crDroid 设备树更贴近其内核分支。
2. 但它们**都不能当 5.10 的基座**（全是 4.14），只能做行为参考 → 见 D002。
3. 5.4 前移树是本项目唯一的现实起点 → 见 F002。
