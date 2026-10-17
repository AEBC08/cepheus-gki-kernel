# D002 — 源码基线与各来源职责

- **状态**：已定
- **日期**：2026-10-17
- **决策者**：PI-Desktop（提案）；用户要求"以 crDroid / RisingOS / Evolution X 为基础，取最后提交最近的"

## 背景

用户原始要求：内核源码与设备树以 crDroid、RisingOS、Evolution X 为基础，取最后提交时间最近的为主。实际盘点结果（F001）与预期有偏差：

- **RisingOS 没有任何公开的 cepheus / sm8150 仓库**（`RisingOS-Revived` org 全量翻页查询为空，`android_kernel_xiaomi_sm8150`、`android_device_xiaomi_cepheus` 均 404）→ 该来源无法作为基线。
- crDroid / Evolution X / Lineage 的 cepheus 内核**全部仍是 4.14.357**，没有一棵 5.x 树。
- 唯一存在的 SM8150 5.x 前移树是社区仓库 `qaz6750/android_kernel_xiaomi_sm8150`（5.4.302）。
- 网络约束（F003）：`android.googlesource.com` / `kernel.googlesource.com` 不可达；GitHub 与 `git.codelinaro.org` 可达。

## 决策

采用**四来源分工**，而不是单一基线：

| 角色 | 来源 | 用途 | 权限 |
|---|---|---|---|
| **GKI 基座** | `github.com/aosp-mirror/kernel_common` @ `android12-5.10`（ACK 的 GitHub 镜像，因 googlesource 不可达） | 内核主干，merge 来源 | 只读上游，定期 merge |
| **vendor 驱动** | `git.codelinaro.org/clo/la/platform/vendor/opensource/{display-drivers,audio-kernel,video-driver,camera-kernel}` 及 `.../qcom-opensource/{data-kernel,wireless}`，取 **msm-5.10 分支**（已验证 `display-kernel.lnx.5.10.*` 存在） | `techpack/*` 与 `qcacld` | 导入 in-tree，保留 remote 以便更新 |
| **cepheus 机型适配** | ①`qaz6750/android_kernel_xiaomi_sm8150@android-5.4.y` 的 `arch/arm64/boot/dts/xiaomi/`（含 cepheus 面板/battery/camera sensor/smb1390 DTS）②4.14 社区树做**行为对照** | 设备树、机型配置 | 移植（改 binding），不做 merge |
| **行为参考（只读）** | `crdroidandroid/android_kernel_xiaomi_sm8150@17.0`（4.14.357，2026-10-11，最新）、`Evolution-X-Devices/kernel_xiaomi_cepheus@bka`（4.14.357，2026-06-26）、`LineageOS/android_kernel_xiaomi_sm8150@lineage-23.2`（4.14.356） | cherry-pick 有价值的机型修复；确认 HAL 期望的行为 | **禁止整树 merge** |

**明确不做的事**：不把四棵 4.14 树合并进 5.10 树。4.14 → 5.10 的整树 merge 冲突量不可控，且会引入无法追溯的 vendor 改动。

## 理由

- **已验证**：crDroid 17.0 分支是 4.14 树里维护最活跃的（2026-10-11），因此它是"参考行为"的最佳来源，但它不能当 5.10 的基座。
- **已验证**：5.4 树已经解决了两件最难的事——SM8150 平台代码与 cepheus 机型 DTS 的前移；把它当"代码来源"而不是"基座"，可以保住这些成果又不继承它已 EOL 的底板。
- **已验证**：CAF 的 msm-5.10 techpack 在 codelinaro 可公开拉取。
- **判断（未验证）**：ACK 的 GitHub mirror 与 googlesource 的 `android12-5.10` 内容一致，但**镜像可能滞后**；若后续发现缺补丁，需要用其它镜像（如 `kernel/common` 的其它 fork）交叉验证。

## 影响与后续

- `src/` 内布局与 remote 名称、merge 策略见 D005。
- 需要记录每个来源的**具体 commit/tag**（可复现性），在 S1 首个构建脚本中固定（pin）而非跟 floating 分支。
- 复核触发：若 CAF msm-5.10 某 techpack 分支与 ACK 5.10 的 UAPI 不匹配，则回退到 msm-5.4 对应模块并做前移。
