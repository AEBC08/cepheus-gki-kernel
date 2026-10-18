# 项目状态快照

- **更新时间**：2026-10-18 11:20 (+08:00)
- **当前阶段**：**路线 C 执行中** —— B1a（clk 框架前移）与 B1（SM8150 时钟驱动）已由 run #22 收口，正在推进 B2
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）
- **目标契约**：`.pi/goal/cepheus-5-10-驱动栈分阶段适配-路线-c-20261018-1001.md`（批次 B1a→B1→B2→B3→B4，逐批以 CI 证据收口）

## 总体判断（F010，已验证）

我们的 cepheus DT 用的是 **CAF 私有 compatible 命名与编号空间**，ACK 5.10 上游驱动只认自己的一套，**绑定层不兼容**：

| 子系统 | 我们 DT | ACK 驱动只认 |
|---|---|---|
| geni-se | `qcom,qupv3-geni-se` | `qcom,geni-se-qup` |
| geni 串口 | `qcom,msm-geni-serial-hs` | `qcom,geni-uart` |
| tsens | `qcom,tsens24xx` | `qcom,tsens-v2` |
| LLCC | `qcom,sm8150-llcc` | `qcom,sc7180-llcc` |
| interconnect | `qcom,sm8150-aggre1_noc` … | `qcom,sm8150-aggre1-noc` …（且 ID 空间完全不同） |
| UFS/USB PHY | `ufs-phy-qmp-v4` / `usb-ssphy-qmp-v2` | `sm8150-qmp-*` 体系 |
| SMMU | `qsmmu-v500` / `ipa-smmu-*` / `kgsl-smmu-v2` | `qcom,smmu-v2` |

上游 5.10 **完全没有** SM8150 的显示（DPU）、相机、kgsl(GPU)、充电驱动。
→ 结论：「能构建」到「能适配」之间隔的是**整套 vendor 驱动栈**，不是几个 CONFIG。故走路线 C（D013/D014）。

## 批次进度

| 批次 | 内容 | 状态 | 证据 |
|---|---|---|---|
| **B1a** | CAF clk 框架前移（`vdd-level.h`、`clk-alpha-pll.[ch]` 等 17 文件，D015 第一批） | ✅ 完成 | run #22，`error:` = 0 |
| **B1** | `camcc/dispcc/npucc/scc-sm8150` 四驱动 | ✅ 完成 | run #22：7 个 `CONFIG_SM_*_8150=y`；`System.map` 符号 cam_cc 11 / disp_cc 12 / npu_cc 12 / scc 9；`Image` 30.1 MB（F013） |
| B2 | pinctrl（复用上游 or 移植） | 进行中 | — |
| B3 | interconnect + LLCC | 待办 | 已量化 ID 空间差异（见 F013 §3、R16） |
| B4 | techpack/display | 待办 | — |

## 仓库与流水线

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| workflows | `bootstrap-sources`(387749275)、`kernel-build`(387749276)、`kernel-5.4-baseline`(388069868) |
| 源码定版 | ACK `android12-5.10` @ `9360e0b02a7f1595661f6a087ef4c439594475a7`（变量 `ACK_SHA`） |
| 内核改动 | `kernel/overlay/`（150 文件）+ `kernel/patches/0001–0004` |
| 已验证产出 | `Image` 30.1 MB + `cepheus-sm8150.dtb`（DTS 告警 2，D012） |
| 5.4 基线 | run #1 成功（27 分 28 秒），产物 `kernel`/`kernel_dtb`/`dtbo.img`（F012） |

## 运行历史

| run | 目标 | 结果 | 结论 |
|---|---|---|---|
| #13 | dtbs | ✅ | QPNP `#size-cells` 修正，告警 31→17 |
| #14 | dtbs | ✅ | adsp/gpr cells 修正，告警 17→2 |
| #15 | Image dtbs | ✅ | 默认目标切为 `Image dtbs`；增量 54 秒 |
| 5.4 #1 | 基线 | ✅ | 该树自带脚本构建成功，artifact 20.99 MB（F012） |
| #16 | Image | ❌ | B1：60 行 error，缺 CAF clk 框架扩展 → 引出 B1a 与 D015（F011） |
| #17–#19 | Image | ❌ | `.init` 签名、`linux/clk/qcom.h`、`clk-debug`、`clk-opp` 三类缺口（F013 §1） |
| #20 | Image | ❌ | 11 行：ACK gcc/gpucc 的上游 TRION ops 命名 vs CAF 命名 |
| #21 | Image | ❌ | 17 行：CAF `dispcc` 需要的 17 个 `DISP_CC_*` ID 在 ACK 头缺失 |
| **#22** | Image | ✅ | **B1a + B1 收口**（F013） |

## 下一步

1. **B2**：pinctrl —— DT 用 `qcom,sm8150-pinctrl`，ACK `pinctrl-sm8150.c` of_match **完全一致**，判定「复用上游」；
   待办：`CONFIG_PINCTRL_SM8150=y` 进 fragment（顺带补 `CONFIG_QCOM_RPMH=y` 让 `CONFIG_QCOM_CLK_RPMH` 生效），
   跑一次构建取 config + `System.map` 证据。
2. **B3**：interconnect（CAF `aggre1_noc` 下划线 vs ACK `aggre1-noc` 连字符，且 ID 表 149 vs 140 项、同名不同值）
   + LLCC（ACK 只有 sc7180 数据表，需前移 CAF `llcc-sm8150.c`）。须做移植决策而非"复用"。
3. **B4**：techpack/display 引入；若 5.10 分支与 ACK 核心不兼容，给出量化证据与替代方案（契约允许）。
4. 收尾回归：`kernel-5.4-baseline` 重跑成功；`kernel-build` 默认 `Image dtbs` 成功且 DTS 告警 ≤ 2。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备可刷、可 9008，暂不刷 | 实机验证推迟（契约边界 1：不做真机操作） | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 相机阶段方向 | 用户 |

## 本机能力边界

- 能：git、Actions API、本地 blob:none 克隆、脚本校验、DT/驱动 compatible 静态比对。
- 不能：本机编译内核；大 pack 拉取/推送；raw 批量下载不稳。
