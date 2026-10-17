# 项目状态快照

- **更新时间**：2026-10-18 01:10 (+08:00)
- **当前阶段**：S1 —— 首次 `Image` 产物验证中
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 仓库与流水线（已验证）

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| 分支 / HEAD | `main` @ `4499f8b` |
| 提交身份 | `AEBC08 <743727279@qq.com>`（仓库级） |
| workflows | `bootstrap-sources` (387749275)、`kernel-build` (387749276) |
| **源码快照** | Release `sources-9360e0b02a7f`，资源 `ack-5.10-9360e0b02a7f.tar.zst`（378.6 MB） |

## 运行历史（真实）

| run | commit | 结果 | 结论 |
|---|---|---|---|
| bootstrap #1 | `0e8db63` | ✅ success | 拿到 ACK `9360e0b0` / display `ecf501e1` 定版（F004） |
| kernel-build #1 | `0e8db63` | ❌ failure | clang `--target` 未定为 arm64 → `unknown register name 'x0'` → 已修（`a7a1cf4`） |
| kernel-build #2 | `a7a1cf4` | ⛔ cancelled | **全对象编译成功**（23 min），死在 full-LTO 链接，收到 runner shutdown signal（F005） |
| kernel-build #3 | `64078df` | ⛔ cancelled | 推送 504 后误用旧 commit，主动取消 |
| kernel-build #4 | `92387ce` | ⛔ cancelled | 用户要求取消 |
| bootstrap #2 | `4499f8b` | ✅ success | 缓存键 v1 生效；新增源码快照打包 + Release 发布步骤均成功 |
| kernel-build #5 | `4499f8b` | ⏳ in_progress | 关 LTO 后的首次完整构建（已 30+ 分钟） |

## 已确认的关键结论

1. **`src/` 为空是设计结果**：`.gitignore` 已收窄为 `/src/kernel/`、`/src/techpack/`；`src/README.md` 已入库解释原因。git 本身也不跟踪空目录。
2. **源码快照已落到项目里**：不是塞进 git 历史，而是发布为 Release 资源（378.6 MB，由 CI 上传，绕过本机网络限制）。见 D008。
3. **缓存浪费已消除**：缓存键改为内容寻址（`src-ack-<pin>-v1` / `ccache-v1` / `out-v1`），不再每轮新建约 1 GB 条目。
4. **关 LTO 的时间取舍**：LTO 开 → 23 min bitcode 编译 + >12 min 单线程 LTO；LTO 关 → 每对象走完整 codegen，编译更慢但省掉 LTO 段，且不受单线程瓶颈影响。

## 下一步

1. 等 kernel-build #5：成功 → 下载 artifact 核对 `Image` 大小 + `build-info.txt`（S1 第 2 步验收正式通过）；失败 → 按日志最小修复。
2. 关闭 R10：确认 CAF `audio-kernel` / `camera-kernel` / `video-driver` 的 5.10 分支名，补 `TECH_BRANCH_*` 仓库变量。
3. 把 `9360e0b0` 写进仓库变量 `ACK_SHA` 固定定版（同时让缓存键变为 `src-ack-9360e0b0...-v1`）。
4. 移植 cepheus DTS（从 5.4 树 `arch/arm64/boot/dts/xiaomi/`）→ `arch/arm64/configs/vendor/cepheus.config` → `TARGETS="Image dtbs"`。
5. S3 前必须移除 `config/bringup-no-lto.config`（D008 复核触发）。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备有、免授权 9008 可用，暂不刷机 | 实机首启验收推迟 | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 影响 techpack/camera 移植方向 | 用户（S2 前） |
| R10 | CAF audio/camera/video 5.10 分支名未确认 | techpack 三件套未拉取 | CI 上继续探测 |

## 本机能力边界

- 能：git（已有 GCM 缓存凭据）、`bash -n`、脚本 `--check`、YAML 校验、Actions API（触发/取消/取日志/取 artifact）。
- 不能：本机编译内核；稳定拉/推约 200 MB 级 git pack（多次 `curl 18`/`504`）。
- 提醒：本机网络会间歇性返回 504，`git push` 需带重试；dispatch 前务必确认远端已有目标 commit（否则会用旧代码跑）。
