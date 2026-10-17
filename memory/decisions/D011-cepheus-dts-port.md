# D011 — cepheus DTS 移植布局与 dt-binding 隔离策略

- **状态**：已定（本轮已实机验证到"dtb 可编译"）
- **日期**：2026-10-18
- **决策者**：PI-Desktop

## 背景

cepheus 的 DTS 只存在于 CAF 体系（4.14 / 5.4 前移树）。ACK `android12-5.10` 自身：

- **已有上游 SM8150 支持**：`arch/arm64/boot/dts/qcom/sm8150.dtsi`（46 KB）+ `sm8150-mtp.dts`，`make dtbs` 能产出 `sm8150-mtp.dtb`（run #7 实测）。
- 但上游 sm8150.dtsi 描述的是"通用 SoC"，没有 display/camera/audio/充电等我们需要的节点。
- CAF 侧（5.4 前移树）有 39 个平台 dtsi（`sm8150.dtsi` 达 101 KB）+ 22 个 cepheus 机型层文件，但依赖：
  - `arch/arm64/boot/dts/qcom/` 路径；
  - CAF 专有的 **dtbo overlay 机制**（`CONFIG_BUILD_ARM64_DT_OVERLAY` + `dtbo-base`），ACK 的 dts Makefile 没有；
  - 一批 **上游不存在的 dt-bindings 头**。

## 决策

### 1. 目录布局：平台层与机型层放同一目录

```
arch/arm64/boot/dts/xiaomi/         ← 我们的 overlay（不覆盖上游 qcom/）
├─ sm8150.dtsi, sm8150-pinctrl.dtsi, …   平台层（34 个，源自 CAF qcom/）
├─ pm8150{,b,l}.dtsi, smb1390.dtsi, msm-wsa881x.dtsi, display/…  平台外围
├─ base/ common/ cepheus/        机型层（源自 CAF xiaomi/）
├─ cepheus-sm8150.dts            入口（顺序 include）
└─ Makefile                      dtb-$(CONFIG_ARCH_QCOM) += cepheus-sm8150.dtb
```

理由：CAF dtsi 之间的 `#include "sm8150-pinctrl.dtsi"` 等是**相对包含**，同目录放置即可原样复用，无需改动 91 个文件；同时**不触碰** `arch/arm64/boot/dts/qcom/sm8150.dtsi`，上游板子保持可编。

### 2. 放弃 dtbo，改为单一 dts

ACK 5.10 的 dts 构建体系没有 CAF 的 overlay 机制。我们把"机型层叠加"改为**顺序 include**，产出普通 `cepheus-sm8150.dtb`，并用 `kernel/patches/0001` 把 `xiaomi/` 挂进 `arch/arm64/boot/dts/Makefile`。

### 3. dt-bindings 隔离：CAF 版一律加 `-cepheus` 私有后缀

**踩过的坑（已验证）**：最初把 CAF 头按原名放进 overlay，覆盖了 ACK 已有的 7 个头
（`dispcc-sm8150` / `gpucc-sm8150` / `videocc-sm8150` / `interconnect icc` / `osm-l3` / `interconnect sm8150` / `rpmh-rsc`），
其中 `icc.h`、`osm-l3.h` 还被其它上游板子共用 → 直接导致**上游** `qcom/sm8150.dtsi` 报 syntax error。

最终规则（确定性，不依赖判断）：

| ACK 是否已有该头 | 处理 |
|---|---|
| 没有 | 用**原名**放入 `kernel/overlay/include/` |
| 已有 | 从 CAF 取内容，写成 `<name>-cepheus.h`，并把使用处 include 重写到私有名 |

依赖通过**本地递归 BFS**一次闭合（而非一轮轮 CI 试错）：从 dts 出发收集 `#include <...>`，逐层解析，直到 CAF 侧无未解析项。最终 30 个头，0 缺失。

## 理由

- **已验证**：上游 `sm8150.dtsi` 在 ACK 5.10 可编译（run #7 的 `sm8150-mtp.dtb`），说明 SoC 级 bindings 齐全，我们只需补 CAF 扩展。
- **已验证**：覆盖上游头会让上游 dtb 一起挂（run #9 的报错即来自 `qcom/sm8150.dtsi`），故必须隔离。
- **已验证**：`-cepheus` 命名 + 递归闭包后，`make dtbs` 一次通过（run #12）。

## 备选方案与否决理由

- **直接覆盖 `qcom/sm8150.dtsi`**：否决。会连上游 demo 板与后续上游更新一起破坏。
- **逐轮 CI 试错补头**：否决。每轮约 20 分钟且只暴露一个缺失，实测浪费 3 轮。
- **手写 cepheus dts（基于上游 sm8150.dtsi）**：暂不。缺少 display/camera/audio/充电节点，等于重写；留作"上游化"长期方向。

## 影响与后续

1. **31 条 `reg_format` 告警**（`pm8150b.dtsi` 等）：CAF 用 `reg = <0x1000>` 配 `#address-cells=1 / #size-cells=0` 的语义，而上游父节点声明 `size-cells=1`。当前只是告警、dtb 可用；**但 S2 点亮 SPMI 子设备（charger/FG/typec）时必须逐个校正**，否则地址/长度解析可能出错。
2. `cepheus-sm8150.dts` 暂未包含 audio overlay 与 `&snd_934x` 的 typec io-channels（等 S2 音频阶段再补）。
3. Q009（多套 EA8076 面板）仍未决：当前平台层 `sm8150-sde-display.dtsi` 与 `common/xiaomi_sm8150-sde-display.dtsi` 会把 5 套面板都编进 dtb，运行时由 panel 匹配逻辑选择——S2 显示阶段再验证。
