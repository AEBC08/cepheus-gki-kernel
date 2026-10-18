# D013 — 基线路线：DT 迎合上游驱动(A) vs 以 vendor 栈为基线(C)

- **状态**：**已定 —— 用户拍板选 C**（2026-10-18）。落地形态见 D014
- **日期**：2026-10-18
- **决策者**：待用户拍板；PI-Desktop 建议 C

## 背景

F010 用真实数据证明：我们的 cepheus DT（CAF 命名体系）与 ACK 5.10 上游驱动（上游命名体系）
**在绑定层就不兼容**（geni/tsens/LLCC/UFS-PHY/USB-PHY/SMMU/interconnect 全不匹配），
而且上游 5.10 **根本没有** SM8150 的显示、相机、GPU(kgsl)、充电驱动。

这解释了用户观察到的现象："项目里的东西比 `qaz6750/android_kernel_xiaomi_sm8150` 少得多"
—— 那份树带的是 CAF LAHAINA(5.4) 完整 vendor 栈，而我们目前只有 DT + 构建流水线。

## 两个选项

### 路线 A：改 DT 去迎合 ACK 上游驱动

- 工作量：重写大量平台节点（geni 串口、tsens、LLCC、UFS/USB PHY、SMMU、interconnect…）为上游命名与属性。
- 能到：**进 init、黑屏**（显示/相机/音频/GPU/充电无驱动）。
- 长期价值：贴近上游，未来可上游化。
- 风险：即使成功，设备也"不能用"，只能证明内核能跑。

### 路线 C：以 vendor 栈为基线，做 5.4 → 5.10 前移（**建议**）

- 基线：`qaz6750/android_kernel_xiaomi_sm8150@android-5.4.y`（ACK android11-5.4 + CAF LAHAINA msm-5.4
  vendor 栈），其 DT 与驱动自洽，作者已实机启动 HyperOS 2。
- 工作：把该树前移到 ACK `android12-5.10`；vendor 代码的 API 适配是主要工作量。
- 能到：**有机会真正"能用"**（显示、充电、触摸等随 vendor 栈一起工作）。
- 已完成的资产仍然有效：构建流水线、overlay/patch 机制、告警处置准则、`-cepheus` 头隔离策略、
  对 CAF/ACK 差异的认识。
- 代价：DT 与部分 overlay 需要回到"与 vendor 栈配套"的形态（我们本来就是从该树导入的，改动很小）。

## 建议

**选 C**，并把原计划的三段式补回来：

1. **S1'**：在 CI 复现 5.4 树的构建（`vendor/sm8150-qgki_defconfig` + 其自带 `build_kernel.sh`），
   产出**已知可启动**的 `Image` 作为参照基线。
2. **S2'**：把基线升级到 ACK `android12-5.10` 内核核心，vendor 栈跟随适配（按子系统分批：
   时钟/pinctrl/rpmh → UFS → 显示 → 触摸/充电 → 音频 → 相机）。
3. **S3'**：模块化（GKI 2.0 形态），恢复 LTO/KASAN/CFI。

## 若用户坚持路线 A

需要明确接受"只能进 init、黑屏"的阶段性结论，并且要投入可观工作重写 DT；收益是内核更贴近上游。
此时 D001（目标 5.10）与 D011（DTS 布局）需要相应修订。

## 复核触发

用户对 A/C 的选择。选定后本记录状态改为"已定"，并在 `docs/roadmap.md` 中重排阶段。
