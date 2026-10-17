# 项目状态快照

- **更新时间**：2026-10-17 23:58 (+08:00)
- **当前阶段**：S1 进行中（CI 已跑通源码拉取；首次 `Image` 构建正在验证）
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 仓库与流水线（已验证）

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| 分支 | `main` |
| 提交身份 | `AEBC08 <743727279@qq.com>`（仓库级） |
| workflows | `bootstrap-sources` (id 387749275)、`kernel-build` (id 387749276) |
| 关键 commits | `0e8db63` 初始 / `0e8db63..` → `cae5081` build 取源码 / `a7a1cf4` 修 clang target |

## 已完成

1. **源码盘点（F001）**：crDroid / Evolution X / Lineage 的仓库、分支、4.14.357 现状；RisingOS 无公开 cepheus 仓库。
2. **5.4 移植树分析（F002）**：`qaz6750@android-5.4.y` 的结构、cepheus DTS 资产、单体传统 boot.img 流程。
3. **环境探针（F003）**：本机无 Linux 构建能力；googlesource 不可达；约 200 MB 级 git pack 稳定失败。
4. **决策 D001–D007**：5.10 定版、四来源分工、KMI 策略、构建环境、仓库/提交规范、CI 流水线、托管与推送。
5. **首次 CI 实测（F004）**：
   - `bootstrap-sources` run #1 **成功**，拿到真实定版：
     - ACK `android12-5.10` @ `9360e0b02a7f1595661f6a087ef4c439594475a7`
     - CAF `display-drivers` @ `display-kernel.lnx.5.10.r8-rel` = `ecf501e10535cf05d1a6a7daaaa6d24e7d62527c`
   - `kernel-build` run #1 失败 → 定位为 clang target 三元组缺失 → 已修（`a7a1cf4`）。

## 进行中

- `kernel-build` **run #2**（commit `a7a1cf4`，run id `39046164126`）：已运行约 30 分钟仍在 `in_progress`。这是本项目**第一次真实内核编译**，目的为产出纯 `gki_defconfig` 的 `Image`（S1 第 2 步验收）。
- 观察地址：`https://github.com/AEBC08/cepheus-gki-kernel/actions/runs/39046164126`

## 下一步（按序）

1. 等 run #2 结果：成功 → 下载 artifact 核对 `build-info.txt` 与 `Image` 大小；失败 → 按日志定位（ccache 已生效，重试会快）。
2. 关闭 R10：确认 CAF `audio-kernel` / `camera-kernel` / `video-driver` 的 5.10 分支名，补 `TECH_BRANCH_*` 仓库变量并重跑 bootstrap。
3. 把 ACK `9360e0b0` 写进仓库变量 `ACK_SHA` 固定定版。
4. 移植 cepheus DTS（从 5.4 树 `arch/arm64/boot/dts/xiaomi/`）→ 新增 `arch/arm64/configs/vendor/cepheus.config` → `TARGETS="Image dtbs"`。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备有、免授权 9008 可用，但用户暂不刷机 | 实机首启验收推迟（S1 末） | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 影响 techpack/camera 移植方向 | 用户（S2 前） |
| R10 | CAF audio/camera/video 5.10 分支名未确认 | techpack 三件套未拉取 | CI 上继续探测 |

## 本机能力边界

- 能做：git 操作（已有 GCM 缓存凭据，可 push）、`bash -n`、脚本 `--check`、YAML 校验、Actions API 查询/触发/取日志与 artifact。
- **不能**：本机编译内核；**不能**稳定拉取约 200 MB 级 git pack（两次失败）。
- 已修正的误判：曾认为「本机无 GitHub 凭据」，实际 Git for Windows 把 `credential.helper=manager` 写在 **system** 作用域（见 F004）。
