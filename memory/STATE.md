# 项目状态快照

- **更新时间**：2026-10-18 04:50 (+08:00)
- **当前阶段**：**S1 第 2、3 步已通过** —— `Image` 与 `cepheus-sm8150.dtb` 均能在 CI 稳定产出；内核改动机制（overlay+patch）已跑通
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 仓库与流水线（已验证）

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| 提交身份 | `AEBC08 <743727279@qq.com>`（仓库级） |
| 源码定版 | ACK `android12-5.10` @ `9360e0b02a7f…`（已设为仓库变量 `ACK_SHA`） |
| 源码快照 | Release `sources-9360e0b02a7f`（172.3 MB，已排除 `.git`） |
| 内核改动 | `kernel/overlay/`（120+ 文件）+ `kernel/patches/0001`（挂 `xiaomi/` 子目录） |
| 稳定构建配方 | `gki_defconfig` + `config/bringup-lite.config`，`LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-`，clang 14，`-j4` |

## 运行历史（真实）

| run | 目标 | 结果 | 结论 |
|---|---|---|---|
| #1–#4 | Image | ❌/⛔ | clang target、LTO 未生效、误跑旧 commit（F004/F005） |
| #5 | Image | ❌ | runner 失联：fragment 符号无效（F006/D009） |
| #6 | Image | ✅ | **首次产出 `Image`** 29.9 MB，18 分 13 秒（F007） |
| #7 | Image dtbs | ✅ | 验证 dtb 管线 + prepare 步骤；上游 `sm8150-mtp.dtb` 可编 |
| #8–#11 | dtbs | ❌ | 逐轮修复：缺 dt-bindings → 覆盖上游头 → 404 假文件 → 再缺头（F008） |
| **#12** | dtbs | ✅ | **`DTC arch/arm64/boot/dts/xiaomi/cepheus-sm8150.dtb` 成功**，31 条 `reg_format` 告警 |

## 已确认的关键结论

1. 内核树不入 git；改动以 overlay+patch 承载，`prepare-kernel.sh` 幂等（reset → overlay → patch），并含 404 假文件防呆。
2. ACK 5.10 自带上游 SM8150 支持；我们的 CAF 平台层放在 `xiaomi/` 同目录，不动上游 `qcom/sm8150.dtsi`。
3. CAF 的 dt-bindings 一律 `-cepheus` 私有后缀，绝不覆盖上游；依赖用本地递归 BFS 一次闭合（30 个头，0 缺失）。
4. 批量下载必须校验内容——`404: Not Found`（14 B）会让 dtc 报 `1.1-4 syntax error`。

## 下一步（按序）

1. **S2 准备**：把 `TARGETS="Image dtbs"` 作为默认；跑一次完整 `Image + dtbs` 确认两者共存（约 20 分钟）。
2. **校正 31 条 `reg_format`**：在平台层覆盖 SPMI 子节点的 `#address-cells/#size-cells` 或逐节点修 `reg`，为 S2 点亮 charger/FG/typec 做准备（R15）。
3. **关闭 R10**：确认 CAF `audio-kernel` / `camera-kernel` / `video-driver` 的 5.10 分支名，把 techpack 拉进来（S2 前置）。
4. **S2 第 1 步**：UFS/pinctrl/RPMh 时钟稳压已在 DT 中；接下来需要内核 config 打开对应驱动并进真机。
5. 真机首启（等用户安排；Q002 已具备 9008 条件）。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备可刷、可 9008，暂不刷 | 实机验证推迟 | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | S2 相机阶段方向 | 用户（S2 前） |
| R10 | CAF audio/camera/video 5.10 分支名未知 | techpack 三件套未拉取 | CI 上继续探测 |

## 本机能力边界

- 能：git（GCM 凭据）、`bash -n`、脚本 `--check`、YAML 校验、Actions API 全套、本地 blob:none 克隆取文件。
- 不能：本机编译内核；稳定拉/推约 200 MB 级 git pack；`raw.githubusercontent.com` 批量下载不稳定（需校验内容 + 用克隆兜底）。
