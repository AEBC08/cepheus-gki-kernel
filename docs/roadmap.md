# 路线图与验收标准

阶段划分的原则：**每个阶段结束时，设备都必须是"可用的"**（能开机、能回退），绝不把设备留在半砖状态。

## S0 — 基线盘点与决策（当前）

**产出**：`memory/decisions/D001–D005`、`memory/findings/F001–F003`、本文件与风险登记册。

**验收**
- [x] 确认所有候选来源的仓库/分支/内核版本/最后提交
- [x] 确认 Android 17 的 AOSP GKI 基线（`android17-6.18`）
- [x] 确认本机无法构建（F003）
- [ ] Q001 构建环境选定 → D004 转为"已定"
- [ ] Q002 真机/救砖条件确认

## S1 — 5.10 底板跑通 + cepheus DTS 移植（单体）

**目标**：产出可刷入的 `boot.img`（`Image` + cepheus DTB）+ `dtbo.img`，实机能进入 `init`（哪怕 HAL 全挂）。

**工作项**
1. 建 `src/kernel/`：ACK `android12-5.10`（pin 到具体 commit）+ CAF msm-5.10 techpack 导入 in-tree。
2. 编译验证**纯 ACK 基线**（无 cepheus 改动）→ 确认工具链与构建脚本正确。
3. 移植 cepheus DTS：从 `qaz6750@android-5.4.y` 的 `arch/arm64/boot/dts/xiaomi/` 迁到 5.10 binding；配置片段 `arch/arm64/configs/vendor/cepheus.config`。
4. 首启验证，收集 `dmesg`/`pstore`。

**验收**
- [ ] 同一份 `Image` 能编出 `Image.gz`、`dtb.img`、`dtbo.img`，且 `build-info.txt` 记录源码 commit + toolchain 版本
- [ ] 实机出现内核日志（UART/pstore/最后内核日志），能定位卡在哪一个驱动
- [ ] 刷回 4.14 `boot.img` 可完整恢复（回退验证必须做，且记录）
- [ ] `scripts/checkpatch.pl --strict` 对我们新增/修改的提交 0 error

## S2 — 子系统点亮（仍是单体）

**目标**：类原生 ROM 能正常日常使用。

**顺序（按依赖与被依赖程度）**
1. UFS + ICE、pinctrl、RPMh 时钟/稳压、interconnect（能到 `init` 之后的第一阶段服务）
2. display（EA8076 面板 + SDE/DPU）+ touch（fts_521）→ 屏幕亮、能触控
3. USB（含 PD/充电识别）+ `smb1390` 充电链路
4. WLAN（qcacld + icnss）、数据（rmnet/IPA）
5. audio（techpack audio + WCD9340 + `mixer_paths.xml` 对齐）
6. camera（techpack camera + CAMX UAPI 兼容）
7. power/thermal/perf（uclamp/EAS、bwmon、thermal zone 与 thermal HAL 对齐）
8. FOD/指纹、AOD

**验收**
- [ ] 逐项给出"DTS 变更 → dmesg 证据 → 用户可见行为"的对应记录
- [ ] 每个子系统单独一个提交（D005），可单独 revert

## S3 — 模块化（GKI 2.0 形态）

**目标**：`Image` 与 vendor `.ko` 分离，验证"换 GKI Image，vendor 模块不变"。

**验收**
- [ ] vendor 模块清单 + 加载顺序 + `/vendor/lib/modules` 部署方案（含 SELinux label）
- [ ] 自有符号白名单 `android/abi_gki_aarch64_cepheus`
- [ ] 一次"仅替换 `Image`、模块不动"的实机启动成功记录

## S4（可选，需重新决策）— 6.1/6.12

只有在 S2/S3 完成后评估：寿命收益 vs 相机/显示重写成本。届时新建决策记录，不复用 D001 的结论。
