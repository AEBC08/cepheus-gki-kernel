# 项目状态快照

- **更新时间**：2026-10-18 05:55 (+08:00)
- **当前阶段**：**S1 收尾** —— `Image` 与 `cepheus-sm8150.dtb` 均稳定产出，DTS 语义类告警已清零；下一阶段进入 S2 驱动点亮
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 仓库与流水线（已验证）

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| 提交身份 | `AEBC08 <743727279@qq.com>`（仓库级） |
| 源码定版 | ACK `android12-5.10` @ `9360e0b02a7f…`（仓库变量 `ACK_SHA`） |
| 源码快照 | Release `sources-9360e0b02a7f`（172.3 MB） |
| 内核改动 | `kernel/overlay/`（123 文件 / 1.08 MB）+ `kernel/patches/0001` |
| 稳定构建配方 | `gki_defconfig` + `config/bringup-lite.config`，clang 14，`LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-`，`-j4` |

## 运行历史（真实，节选）

| run | 目标 | 结果 | 结论 |
|---|---|---|---|
| #6 | Image | ✅ | 首次产出 `Image` 29.9 MB（18 分 13 秒），F007 |
| #7 | Image dtbs | ✅ | dtb 管线 + prepare 步骤验证 |
| #8–#11 | dtbs | ❌ | 缺 dt-bindings → 覆盖上游头 → 404 假文件 → 再缺头（F008） |
| #12 | dtbs | ✅ | **首个 `cepheus-sm8150.dtb`**，31 条告警 |
| #13 | dtbs | ✅ | PNP `#size-cells` 修正后 **31 → 17** 条告警 |
| #14 | dtbs | ✅ | adsp/gpr cells 修正后 **17 → 2** 条（仅 `trusty.dtsi` 的 ranges_format，D012 记录为接受） |

## 已确认的关键结论

1. 内核改动走 overlay + patch，`prepare-kernel.sh` 幂等并含 404 假文件防呆。
2. ACK 5.10 自带上游 SM8150 支持；CAF 平台层放 `xiaomi/` 同目录，不动上游 `qcom/sm8150.dtsi`。
3. CAF dt-bindings 一律 `-cepheus` 私有后缀；依赖用本地递归 BFS 一次闭合（30 个头）。
4. DTS 告警处置有明确准则（D012）：语义类（reg/cells/ranges）必修，提示类需写明理由才可接受。
5. techpack 来源（F009）：**display 有 5.10 分支**；**audio / camera / video 只有 release tag**，必须按 tag 选型。

## 下一步（按序）

1. **S2 第 1 步（真机前）**：确认 `TARGETS="Image dtbs"` 作为默认目标；把 `cepheus-sm8150.dtb` 打包进 boot/dtbo 的流程确定下来（ROM 侧配合）。
2. **techpack：先接 display**（分支已确认 `display-kernel.lnx.5.10.r8-rel`），验证 `techpack/display` 能编进内核。
3. **audio/camera/video 的 tag 选型**（R10 未关闭）：按 F009 §3 的规则挑 tag，先做"能否编译"的探针。
4. 真机首启（等用户安排；Q002 已具备 9008 条件）。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备可刷、可 9008，暂不刷 | 实机验证推迟 | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | S2 相机阶段方向 | 用户（相机接入前） |
| R10 | audio/camera/video 走 tag，具体 tag 未定 | 三个 techpack 未拉取 | 下一轮按 F009 规则选型 |

## 本机能力边界

- 能：git、Actions API 全套、本地 blob:none 克隆取文件、脚本 `bash -n` / `--check`、YAML 校验、DTS 静态分析。
- 不能：本机编译内核；大 pack 拉取/推送；`raw.githubusercontent.com` 批量下载不稳（须校验内容 + 克隆兜底）。
