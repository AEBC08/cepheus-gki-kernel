# 项目状态快照

- **更新时间**：2026-10-17 23:05 (+08:00)
- **当前阶段**：S0 收尾 → S1 准备（源码落地与首次构建待 GitHub 仓库就绪）
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 已完成

1. **源码盘点（F001）**：确认 crDroid / Evolution X / Lineage 的 sm8150、cepheus 内核与设备树仓库、分支、内核版本、最后提交时间；确认 RisingOS 无公开 cepheus/sm8150 仓库。
2. **5.4 移植树分析（F002）**：确认 `qaz6750/android_kernel_xiaomi_sm8150@android-5.4.y` 是 ACK android11-5.4 + CAF LAHAINA msm-5.4 techpack + SM8150/cepheus DTS 的前移成果；单体编译、传统 boot.img 流程。
3. **环境探针（F003）**：本机 Windows 11 IoT LTSC / i5-2430M 2C4T / 7.9 GB RAM，无 WSL、无 Docker、无 clang/make；`android.googlesource.com` 与 `kernel.googlesource.com` 不可达；GitHub 与 `git.codelinaro.org` 可达。
4. **决策 D001–D006**：目标版本 5.10（D001）、四来源分工（D002）、模块化/KMI 策略（D003）、构建环境已定（D004）、仓库与提交规范（D005）、CI 流水线（D006）。
5. **脚本与流水线**（本轮产出，已做本机可验证部分）：
   - `scripts/fetch-sources.sh`（ACK + CAF techpack 拉取，带重试、版本校验、PINS 记录）
   - `scripts/build-kernel.sh`（配置合并、编译、产物收集、`build-info.txt`）
   - `.github/workflows/bootstrap-sources.yml`、`.github/workflows/kernel-build.yml`
   - 验证结果：两个脚本 `bash -n` 通过；`build-kernel.sh --check` 在桩内核树上**通过**（版本/工具链/片段解析均正常）、在缺树与缺片段时**正确报错**；两个 workflow YAML 解析通过。

## 进行中

- 无（S1 的首个动作被 Q007 阻塞：需要 GitHub 仓库才能跑 CI）。

## 下一步（按序）

1. 用户建立 GitHub 仓库（Q007）→ 推送到 GitHub → 手动触发 `bootstrap-sources`，拿到 `PINS.txt` 与 `kernel-files.txt`。
2. 依据 PINS 固定 ACK commit；确认 CAF `audio-kernel` / `camera-kernel` / `video-driver` 的 5.10 分支名（R10）。
3. 触发 `kernel-build`（纯 `gki_defconfig`，无机型片段）→ 得到第一个 `Image` 产物（S1 第 2 步验收）。
4. 移植 cepheus DTS（从 `src/ref-5.4` 或 5.4 树取），新增 `arch/arm64/configs/vendor/cepheus.config`，目标 `TARGETS="Image dtbs"`。

## 阻塞项

| 编号 | 阻塞内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q007 | GitHub 仓库尚未创建（Actions 需要） | 无法跑 bootstrap / build | 用户提供仓库地址或授权 |
| Q010 | 推送认证方式未定 | 无法创建仓库/首次推送（仓库创建后即可跑 CI） | 用户选择 D007 中 A/B/C |
| Q002-刷机 | 设备有、可免授权 9008，但用户暂不刷机 | S1 实机首启验收推迟 | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 影响 techpack/camera 移植方向 | 用户（可延后到 S2） |

## 本机能力边界（避免误判）

- 能在本机做：`bash -n`、脚本 `--check` 逻辑自测、YAML/文档校验、小体积 git 元数据操作（`--filter=blob:none`）。
- **不能**在本机做：内核编译（无 Linux/工具链）、~200 MB 级 git 拉取（网络不稳定，两次失败）、真机刷写（用户暂不刷）。

## 已知风险（摘要，详见 docs/risk-register.md）

ION/dma-heap、相机栈、显示+FOD、音频 mixer 耦合、电源与调度模型差异、启动链无 vendor_boot、网络承载力、脚本尚未在真实 Linux 上跑通。
