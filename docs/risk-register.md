# 风险登记册

等级：**高**=可能直接导致方案不可行；**中**=显著增加工作量；**低**=可控。

| ID | 风险 | 等级 | 依据 | 缓解措施 | 何时验证 |
|---|---|---|---|---|---|
| R1 | **ION / dma-heap 断裂**：4.14 世代的 gralloc、camera、display HAL 依赖 `ION_IOC_*`；5.10 中 ION 已被 dma-heap 取代 | 高 | CAF 5.4 树里仍留有 `ion` 兼容垫片（该树有 `ion: silence legacy system heap allocation warning` 提交）→ 说明兼容层存在但需实测 | 优先确认 CAF msm-5.10 是否保留 ion legacy 兼容；必要时 backport CAF ion 兼容层或提供 32/64 位 ioctl shim | S1 末 / S2 显示阶段第一步 |
| R2 | **相机栈**：CAMX 与 techpack camera 的 `cam_sync`/ioctl/media-controller 语义强耦合 | 高 | 4.14 CAMX 为闭源，无法修改 | 策略为"保留 4.14 UAPI 语义，只换内核实现"，不跟随新 HAL（Q005）；必要时把 msm-5.4 的 camera techpack 前移而非用 5.10 版 | S2 第 6 步 |
| R3 | **显示 + FOD**：EA8076 面板驱动与 `sde_connector` 的指纹/AOD vendor hook 在 5.10 变为 DPU 结构 | 中高 | 5.4 树有 5 套面板 dtsi；FOD 依赖 display 与 touch 联动 | 以 5.4 树的面板驱动为蓝本移植；FOD 通路单独做回归清单 | S2 第 2 步 |
| R4 | **音频 mixer 耦合**：`mixer_paths.xml` 与 techpack audio 的 kcontrol 名逐条对应 | 中高 | 5.4 树合并的是 `LA.UM.9.14.r1 QSSI16.0` audio-kernel，说明作者已踩过 | 保持 kcontrol 命名与 4.14 一致；DTS 与 mixer xml 同步修改 | S2 第 5 步 |
| R5 | **启动链**：无 `vendor_boot`/`vendor_dlkm` 物理分区，GKI 官方模块加载链不可用 | 中 | 已验证 5.4 树走传统 boot.img（`Image.gz` + `dtb.img` + `dtbo.img`） | 模块放 `/vendor/lib/modules` + vendor init modprobe（D003）；不伪造 `vendor_dlkm` | S3 |
| R6 | **电源/调度模型差异**：4.14 的 schedtune/core_ctl/`msm_performance` 在 5.10 变为 uclamp/EAS | 中 | 上游 5.10 已移除 schedtune 的部分用法 | 预期性能/续航先退一步；按 subsystem 逐个调 bwmon/memlat/thermal；把调参独立成提交便于回退 | S2 第 7 步 |
| R7 | **多来源合并成本**：4 棵 4.14 + 1 棵 5.4 + ACK + CAF 同时维护 | 中 | D002/D005 | 4.14 只做 cherry-pick 参考，不设 remote 整树 merge；`ack-5.10` 与 `cepheus-5.10` 分支隔离 | 持续 |
| R8 | **构建环境**：本机 2C4T/8 GB 且无 Linux | ~~中~~ **已关闭** | F003 | Q001 已决：CI 为主（D004/D006） | 已验证：脚本与 workflow 已落地并通过本机可做的校验 |
| R9 | **镜像滞后**：ACK 走 GitHub 镜像而非 googlesource | 低 | googlesource 不可达 | 记录 pin 的 commit；需要某补丁时用其它 fork 交叉验证 | 持续 |
| R10 | **CAF camera 仓库路径/分支未确认** | 低 | `qcom-opensource/camera-kernel` 404 | S1 用 GitLab API 枚举确认正确 project 路径 | S1 第 1 步 |
| R11 | **面板变体**：cepheus 存在多套 EA8076（f1/f1mp/f1p2…） | 低 | 5.4 树有 5 个面板 dtsi | 沿用 5.4 树的选择逻辑，或 DTBO 内多面板 + 运行时判定（Q009） | S1 第 3 步 |
| R12 | **`Image` 体积超 boot 分区** | 低中 | 单体 + LTO 关闭时体积上升 | 实测 boot 分区大小；超限则提前模块化或启用 LTO | S1 末 |
| R13 | **本机网络承载力**：~200 MB 级 git pack 稳定中断（两次实测） | 中 | D006 背景 / F003 补充 | 源码 bulk 拉取全部移到 CI；本地只做小体积操作 | 持续 |
| R14 | **脚本尚未在真实 Linux / CI 上跑通**：`build-kernel.sh` 只通过语法与桩环境 `--check` | 中 | 本轮验证记录 | 首次 CI run 即为真实验证；失败按日志最小修复，并在提交信息写清 | S1 第 3 步 |

## 使用规则

- 风险等级变化必须更新本表，并在 `memory/decisions/` 留下记录（若因此改变方案）。
- 风险一旦被验证为不存在（例如 R1 实测通过），改为"已关闭"并注明验证方式与证据。
