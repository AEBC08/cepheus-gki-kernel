# 项目状态快照

- **更新时间**：2026-10-18 07:10 (+08:00)
- **当前阶段**：**战略决策点** —— 发现 DT 与上游驱动体系不兼容（F010），需在路线 A / C 之间选择（D013，待拍板）
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 本轮新增的关键认知（F010，已验证）

我们的 cepheus DT 用的是 **CAF 私有 compatible 命名**，ACK 5.10 上游驱动只认上游命名，**绑定层不兼容**：

| 子系统 | 我们 DT | ACK 驱动只认 |
|---|---|---|
| geni-se | `qcom,qupv3-geni-se` | `qcom,geni-se-qup` |
| geni 串口 | `qcom,msm-geni-serial-hs` | `qcom,geni-uart` |
| tsens | `qcom,tsens24xx` | `qcom,tsens-v2` |
| LLCC | `qcom,sm8150-llcc` | `qcom,sc7180-llcc` |
| UFS/USB PHY | `ufs-phy-qmp-v4` / `usb-ssphy-qmp-v2` | `sm8150-qmp-*` 体系 |
| SMMU | `qsmmu-v500` / `ipa-smmu-*` / `kgsl-smmu-v2` | `qcom,smmu-v2` |

且上游 5.10 **完全没有** SM8150 的显示（DPU 无 sm8 文件）、相机、kgsl(GPU)、充电驱动。
→ 结论：「能构建」到「能适配」之间隔的是**整套 vendor 驱动栈**，不是几个 CONFIG。

## 仓库与流水线

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| workflows | `bootstrap-sources`(387749275)、`kernel-build`(387749276)、**`kernel-5.4-baseline`(388069868)** |
| 源码定版 | ACK `android12-5.10` @ `9360e0b02a7f…`（变量 `ACK_SHA`） |
| 内核改动 | `kernel/overlay/`（123 文件）+ `kernel/patches/0001` |
| 已验证产出 | `Image` 29.9 MB；`cepheus-sm8150.dtb`（DTS 告警 31→2，D012） |
| 5.4 基线 | run #1 进行中：复现 `qaz6750@android-5.4.y` 的产物作为"已知可启动"参照 |

## 运行历史（本轮新增）

| run | 目标 | 结果 | 结论 |
|---|---|---|---|
| #13 | dtbs | ✅ | QPNP `#size-cells` 修正，告警 31→17 |
| #14 | dtbs | ✅ | adsp/gpr cells 修正，告警 17→2 |
| #15 | Image dtbs | ✅ | 默认目标切为 `Image dtbs`，两者共存；增量 54 秒 |
| 5.4 #1 | 基线 | ⏳ | 用该树自带脚本构建（LTO 已由 CI 关闭），进行中 |

## 下一步（取决于 D013 决策）

### 若选 C（以 vendor 栈为基线，建议）
1. 等 5.4 基线构建成功 → 得到"已知可启动"的 Image 与 DT 作为参照。
2. 规划 5.4 → 5.10 前移：先做"内核核心换成 ACK android12-5.10 + vendor 栈跟随适配"，
   按子系统分批（时钟/pinctrl/rpmh → UFS → 显示 → 触摸/充电 → 音频 → 相机）。
3. 我们的 overlay/patch 机制、告警准则、`-cepheus` 头策略继续沿用。

### 若选 A（改 DT 迎合上游）
1. 把 geni/tsens/LLCC/PHY/SMMU/interconnect 节点改写为上游命名与属性。
2. 明确接受阶段结论：**进 init、黑屏**（显示/相机/音频/GPU/充电无驱动）。
3. 修订 D001/D011。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| **D013** | 路线 A / C 未定 | 后续所有工作量分配 | **用户拍板** |
| Q002-刷机 | 设备可刷、可 9008，暂不刷 | 实机验证推迟 | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 相机阶段方向 | 用户 |

## 本机能力边界

- 能：git、Actions API、本地 blob:none 克隆、脚本校验、DT/驱动 compatible 静态比对。
- 不能：本机编译内核；大 pack 拉取/推送；raw 批量下载不稳。
