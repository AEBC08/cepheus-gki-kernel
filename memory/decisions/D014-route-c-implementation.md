# D014 — C 路线的落地形态：ACK 5.10 核心 + 公开 CAF techpack + SM8150 平台移植

- **状态**：已定（承接 D013 的路线 C）
- **日期**：2026-10-18
- **决策者**：用户选定路线 C；实现方式由 PI-Desktop 依实测确定

## 背景：C 路线有两种可能形态，一种被事实否定

| 形态 | 说明 | 可行性 |
|---|---|---|
| C2：以 **CAF msm-5.10 完整内核**为基线 | 若 Qualcomm 的 vendor 内核分支公开，vendor 栈与 5.10 天然匹配 | **不可行（已验证）** |
| C1：**ACK 5.10 核心 + 公开 CAF techpack + SM8150 平台代码移植** | vendor 驱动来自公开的 techpack 仓库（5.10 分支/tag），平台代码从 5.4 树搬 | **可行，采用** |

C2 被否定的证据（GitLab API 实测）：

- `clo/la/kernel/msm-5.10` 默认分支 `aosp-new/caf2/caf2/clo/main` 是**上游味**的 caf2 分支：
  - 没有 `techpack/` 目录（404）
  - `drivers/soc/qcom` 只有 12 个文件（vanilla 上游规模），`drivers/interconnect/qcom` 也不存在
- 也就是说 Qualcomm 的 **vendor 内核分支不公开**；公开的是 AOSP caf2 变体 + 拆分的 techpack 仓库。

这与 5.4 前移树的作者做法一致（他那棵树也是 ACK 4.14/5.4 + 公开 LAHAINA techpack + 自写 SM8150 平台代码）。

## 工作地图（已实测）

把 5.4 前移树里**文件名含 sm8150 的非 DT 文件**统计出来，共 **31 个**——这就是平台层要搬的量：

| 类别 | 数量 | 文件 |
|---|---|---|
| 时钟 | 10 | `camcc/dispcc/gpucc/npucc/scc/videocc/gcc/debugcc-sm8150.c`、`vdd-level-sm8150.h`、`virtio_clk_sm8150.c` |
| pinctrl | 1 | `pinctrl-sm8150.c` |
| interconnect | 1 | `sm8150.c` |
| LLCC | 1 | `llcc-sm8150.c` |
| techpack 配置/头 | 6 | `audio/asoc/sm8150.c`、`msm_sm8150_dailink.h`、`config/*sm8150*.conf` |
| dt-bindings | 9 | `include/dt-bindings/**/*sm8150*.h` |
| 构建配置 | 3 | `arch/arm64/configs/vendor/sm8150*-qgki_defconfig`、`xiaomi/sm8150-common.config` |
| 设备树 | 84 | 已导入（`kernel/overlay`，D011） |

**关键判断**：vendor 代码的绝大部分是 **SoC 通用**（LAHAINA 一代），SM8150 只需要这一薄层平台代码。所以移植面是**有界的**，不是"搬一棵内核"。

## 决策

1. **基线不动**：ACK `android12-5.10` 作为内核核心（D001 不变）。
2. **平台层分批移植**（每批独立可编译验证）：
   - **B1 时钟**：camcc / dispcc / npucc / scc / debugcc-sm8150 + `vdd-level-sm8150.h`
   - **B2 pinctrl**：`pinctrl-sm8150.c`（若 ACK 的版本不足以支持 CAF DT 的引脚，则替换/补充）
   - **B3 interconnect / LLCC**：`sm8150.c`、`llcc-sm8150.c`
   - **B4 techpack**：display（5.10 分支）→ audio/camera/video（按 F009 的 tag 规则）
   - **B5 其它 vendor 驱动**：kgsl、icnss/qcacld、qpnp-smb5 等
3. **已存在的上游实现优先复用**：ACK 已有 `gcc-sm8150.c`/`gpucc-sm8150.c`/`videocc-sm8150.c`/`pinctrl-sm8150.c`/`interconnect/sm8150.c`，
   先尝试**不替换**、只补缺（camcc/dispcc/npucc/scc/debugcc）；若出现 clock ID 编号不一致导致的问题，再评估替换。
4. **每批的验收**：`Image dtbs` 构建通过 + 该子系统的 of_match 与 DT 对得上（F010 的核对方法复用）。

## 首批（B1）的具体做法

> **B1 已实测（run #16，见 F011）**：驱动不能直接搬——CAF 扩展了 clk 框架
> （`vdd-level.h` 的 `DEFINE_VDD_REGULATORS`、`clk-alpha-pll` 的 Trion PLL），
> ACK 5.10 没有。因此插入前置批次 **B1a：clk 框架扩展前移**（见 D015）。

- 把 5 个 clk 驱动 + `vdd-level-sm8150.h` 放进 `kernel/overlay/drivers/clk/qcom/`
- 用 `kernel/patches/` 在 `drivers/clk/qcom/{Kconfig,Makefile}` 里登记（patch 而非覆盖）
- `config/bringup-cepheus.config` 打开对应 `CONFIG_*`（built-in）
- 构建验证：先只求编译通过；binding 与运行时行为留待实机/后续

## 风险与复核

- **API 差异**：5.4 的 clk 驱动用的 `clk-alpha-pll`/`clk-rcg2` 接口在 5.10 基本稳定，但 `debugcc`、`virtio_clk` 可能引用了 5.4 专有设施 → 编译错误即为量化指标。
- **clock ID 编号**：CAF 头与上游头可能不同（我们用 `-cepheus` 私有头规避了覆盖），但 CAF 驱动的 `clk_ops` 表是按 CAF 头写的；
  若上游 `gcc-sm8150.c` 与 CAF DT 的 ID 不一致，表现为挂钟错乱 → 届时按 F010 方法逐项核对，必要时替换为 CAF 版 gcc 驱动。
- 复核触发：B1 编译错误量过大（>100 处）说明该批不适合直接搬，需要改用"以 5.4 驱动为蓝本重写"的方式。
