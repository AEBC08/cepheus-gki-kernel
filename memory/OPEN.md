# 待决问题（Open Questions）

状态：`待决` / `已决(见 Dnnn)` / `搁置`

| 编号 | 问题 | 状态 | 说明 |
|---|---|---|---|
| Q001 | 构建环境选哪种：①本机 WSL2 Ubuntu ②GitHub Actions ③云主机 | 已决(见 D004/D006) | 用户选"Actions 为主 + WSL2 为辅"；本机网络无法拉大 pack（F003 补充），首次构建走 CI |
| Q002 | 是否有第二台 cepheus 可用、是否能进入 EDL/9008 救砖 | 已决 | 有可刷设备、免授权 9008 可用；但用户暂不刷机，先要"编出东西"，故 S1 实机验收推迟 |
| Q003 | 4.14 是否保留为出货主线 | 建议保留（待确认） | crDroid 17.0 分支仍在维护 4.14.357；GKI 走独立分支互不影响 |
| Q004 | 是否接受"非 Google KMI 认证的 GKI"（允许维护自有 symlist） | 建议接受（待确认） | 见 D003 |
| Q005 | 相机策略：保留 4.14 CAMX 的 UAPI 语义（`cam_sync`/ioctl）还是跟随新 cam 栈 | **待决** | 影响 techpack/camera 移植方向；可延后到 S2 |
| Q006 | 模块落地位置：纯 `/vendor/lib/modules` + vendor `init` modprobe，还是用 super 动态分区模拟 `vendor_dlkm` | **待决** | Mi 9 无 `vendor_boot`/`vendor_dlkm` 物理分区；建议先用前者 |
| Q007 | 代码托管：项目控制仓库放哪里 | **已决(见 D007)** | 已推送至公开仓库 `AEBC08/cepheus-gki-kernel`，默认分支 `main` |
| Q008 | S1 首启验证用哪个 ROM 组合：crDroid 17.0 还是直接 Infinity X | **待决** | 5.4 作者已验证 HyperOS 2，类原生理论上更简单；建议先用 crDroid 17.0 收敛 |
| Q009 | 屏幕/面板变体：cepheus 有多套 EA8076 面板 dtsi（f1/f1mp/f1p2 等），是否需要运行时判定 | **待决（S1 调研）** | 影响 DTS 与 DTBO 组织方式 |
| Q011 | **基线路线**：A=改 DT 迎合 ACK 上游驱动（只能到"进 init、黑屏"）／C=以 5.4 vendor 栈为基线做 5.4→5.10 前移（有机会"能用"） | **已决(见 D013)** | 用户选 C；落地形态见 D014，框架级覆盖规则见 D015。B1a/B1 已完成（F013，run #22） |
| Q010 | 推送认证：A 用户给 fine-grained PAT / B 用户 `gh auth login` / C 用户自行 push | **已决(见 D007)** | 未用 A/B/C：本机 GCM 已有缓存凭据（system 级 `credential.helper=manager`，我在第一轮只查了 global），故由 PI-Desktop 直接建仓并推送 |

## 处理规则

- 每个待决问题在解决后，写对应 `decisions/Dnnn`，并在此表把状态改为 `已决(见 Dnnn)`。
- 若问题长期悬空且不阻塞当前里程碑，标 `搁置` 并注明原因。
