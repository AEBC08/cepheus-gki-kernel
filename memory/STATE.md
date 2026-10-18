# 项目状态快照

- **更新时间**：2026-10-18 13:30 (+08:00)
- **当前阶段**：**B1a / B1 / B2 / B3 已完成**；B4 判定为「不能内建」，已给出量化证据与替代方案（D016）
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）
- **目标契约**：`.pi/goal/cepheus-5-10-驱动栈分阶段适配-路线-c-20261018-1001.md`（批次 B1a→B1→B2→B3→B4）

## 总体判断（F010，已验证）

我们的 cepheus DT 用的是 **CAF 私有 compatible 命名与编号空间**，ACK 5.10 上游驱动只认自己的一套，**绑定层不兼容**：

| 子系统 | 我们 DT | ACK 驱动只认 |
|---|---|---|
| geni-se | `qcom,qupv3-geni-se` | `qcom,geni-se-qup` |
| geni 串口 | `qcom,msm-geni-serial-hs` | `qcom,geni-uart` |
| tsens | `qcom,tsens24xx` | `qcom,tsens-v2` |
| LLCC | `qcom,sm8150-llcc` | 上游只有 `qcom,sc7180-llcc`（B3 已用 patch 0005 补 sm8150 表） |
| interconnect | `qcom,sm8150-aggre1_noc` … | `qcom,sm8150-aggre1-noc` …（B3 已对齐 10 个 compatible） |
| UFS/USB PHY | `ufs-phy-qmp-v4` / `usb-ssphy-qmp-v2` | `sm8150-qmp-*` 体系 |
| SMMU | `qsmmu-v500` / `ipa-smmu-*` / `kgsl-smmu-v2` | `qcom,smmu-v2` |

上游 5.10 **完全没有** SM8150 的显示（DPU）、相机、kgsl(GPU)、充电驱动。
→ 结论：「能构建」到「能适配」之间隔的是**整套 vendor 驱动栈**，不是几个 CONFIG。故走路线 C（D013/D014）。

## 批次进度

| 批次 | 内容 | 状态 | 证据 |
|---|---|---|---|
| **B1a** | CAF clk 框架前移（`vdd-level.h`、`clk-alpha-pll.[ch]` 等 17 文件，D015 第一批） | ✅ | run #22，`error:` = 0（F013） |
| **B1** | `camcc/dispcc/npucc/scc-sm8150` 四驱动 | ✅ | run #22：7 个 `CONFIG_SM_*_8150=y`；符号 cam_cc 11 / disp_cc 12 / npu_cc 12 / scc 9；`Image` 30.1 MB（F013） |
| **B2** | pinctrl（复用上游） | ✅ | run #23：`CONFIG_PINCTRL_SM8150=y`；`sm8150_pinctrl` 7 个符号；of_match 一致（F014） |
| **B3** | interconnect + LLCC | ✅ | run #24/#25：`CONFIG_INTERCONNECT_QCOM_SM8150=y`、`CONFIG_QCOM_LLCC=y`、`sm8150_cfg` 符号；`cepheus-sm8150.dtb` 463 KB（F015） |
| **B4** | techpack/display | ⚠️ **判定不可内建** | run #27 取证：`msm/Kbuild` 用 `obj-m`、`msm/{sde,dsi,dp}` 无构建规则、入口是 `CONFIG_DRM_MSM`（与 ACK 同名驱动冲突）；run #28 模块化探针 return 0 但 **0 个 .ko**（F016 + D016） |

## 仓库与流水线

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| workflows | `bootstrap-sources`(387749275)、`kernel-build`(387749276)、`kernel-5.4-baseline`(388069868) |
| 仓库变量 | `ACK_SHA = 9360e0b02a7f1595661f6a087ef4c439594475a7`；`TECH_BRANCH_DISPLAY = display-kernel.lnx.5.10.r8-rel` |
| 内核改动 | `kernel/overlay/`（151 文件）+ `kernel/patches/0001–0006` |
| 已验证产出 | `Image` 30.34 MB + `cepheus-sm8150.dtb` 463 KB（DTS 告警 2，D012） |
| 5.4 基线 | run #1 成功（27 分 28 秒，F012）；run #2 为本次回归 |

## 运行历史

| run | 目标 | 结果 | 结论 |
|---|---|---|---|
| #13–#15 | dtbs / Image dtbs | ✅ | DTS 告警 31→2；默认目标切为 `Image dtbs` |
| 5.4 #1 | 基线 | ✅ | 该树自带脚本构建成功，artifact 20.99 MB（F012） |
| #16 | Image | ❌ | B1：60 行 error，缺 CAF clk 框架扩展 → 引出 B1a 与 D015（F011） |
| #17–#19 | Image | ❌ | `.init` 签名、`linux/clk/qcom.h`、`clk-debug`、`clk-opp` 三类缺口 |
| #20 | Image | ❌ | 11 行：上游 TRION ops 命名 vs CAF 命名 |
| #21 | Image | ❌ | 17 行：CAF `dispcc` 需要的 `DISP_CC_*` ID 在 ACK 头缺失 |
| **#22** | Image | ✅ | **B1a + B1 收口**（F013） |
| **#23** | Image | ✅ | **B2 收口**（F014） |
| **#24** | Image | ✅ | interconnect 链路打通（F015） |
| **#25** | Image dtbs | ✅ | **B3 收口**，含 LLCC patch 与 DTB 产物（F015） |
| #26 | Image | ✅ | B4 首探：display 源码进树成功；暴露 `CONFIG_DISPLAY_BUILD` 不在 Kconfig（F016） |
| #27 | Image | ✅ | B4 取证：拿到 `obj-` 规则全貌，定性"不可内建"（F016） |
| #28 | Image | ✅ | B4 模块化探针：return 0 但 0 个 `.ko`，根因已定位（F016） |

## 下一步

1. **B4 转入 S2 实施**（D016）：模块化构建 + 独立 `.config`，解决 `CONFIG_DRM_MSM` 撞名与 KMI 导出约束。
   在那之前不能声称"显示栈已接入"。
2. **真机验证阶段**（需用户明确指令，契约边界 1）优先确认的三项未验证假设：
   - interconnect 的 DT cell 仍是 CAF 全局编号，ACK 期望 provider 内索引（F015 §4）；
   - LLCC 切片表数值未与硬件核对（F015 §4）；
   - `qcom,bcm-voter` 能否从 cmd_db 拿到地址（F015 §4）。
3. 相机/音频/video 的 techpack tag 选型（F009、Q005）。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备可刷、可 9008，暂不刷 | 实机验证推迟（契约边界 1） | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 相机阶段方向 | 用户 |
| D016-后续 | display 模块化的 KMI 导出 | B4 完成度 | 后续 S2 工作 |

## 本机能力边界

- 能：git、Actions API、本地 blob:none 克隆、脚本校验、DT/驱动 compatible 静态比对。
- 不能：本机编译内核；大 pack 拉取/推送；raw 批量下载不稳（CAF git 站点会 429 限流）；
  本机下载大 artifact 常超时。
