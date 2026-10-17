# 项目状态快照

- **更新时间**：2026-10-18 03:25 (+08:00)
- **当前阶段**：**S1 第 2 步已通过** —— CI 能稳定产出可用的 arm64 `Image`；下一步进入 cepheus 机型适配
- **目标**：cepheus 运行 ACK `android12-5.10` GKI 2.0 内核，服务类原生 ROM（终极目标 Infinity X / Android 17）

## 仓库与流水线（已验证）

| 项 | 值 |
|---|---|
| GitHub | `https://github.com/AEBC08/cepheus-gki-kernel`（公开） |
| 提交身份 | `AEBC08 <743727279@qq.com>`（仓库级） |
| workflows | `bootstrap-sources` (387749275)、`kernel-build` (387749276) |
| **源码定版** | ACK `android12-5.10` @ `9360e0b02a7f1595661f6a087ef4c439594475a7`；CAF display-drivers @ `ecf501e10535cf05d1a6a7daaaa6d24e7d62527c` |
| **源码快照** | Release `sources-9360e0b02a7f`（378.6 MB，含 `.git`；下次重打会排除） |
| **最新可用产物** | artifact `kernel-cepheus-5.10-6`：`Image` 28.5 MiB + `System.map` + `build-info.txt` |

## 运行历史（真实）

| run | commit | 结果 | 结论 |
|---|---|---|---|
| bootstrap #1 | `0e8db63` | ✅ | 拿到 ACK/display 定版（F004） |
| kernel-build #1 | `0e8db63` | ❌ | clang `--target` 未定 arm64（已修 `a7a1cf4`） |
| kernel-build #2 | `a7a1cf4` | ⛔ 取消 | 全对象编译成功（23 min），死在 full LTO，runner shutdown（F005） |
| kernel-build #3 | `64078df` | ⛔ 取消 | 推送 504 后用旧 commit 误跑 |
| kernel-build #4 | `92387ce` | ⛔ 取消 | 用户要求 |
| bootstrap #2 | `4499f8b` | ✅ | 缓存键 v1 + 源码快照 Release 均成功 |
| kernel-build #5 | `4499f8b` | ❌ | **runner 失联**（65 min 未完成）：fragment 符号写错，LTO/KASAN 仍在（F006、D009） |
| **kernel-build #6** | `614b46b` | ✅ **成功** | 构建 18 min 13 s；`Image` 29.9 MB，magic `ARMd` 校验通过（F007） |

## 已确认的关键结论

1. `src/` 空是设计：`.gitignore` 只忽略 `/src/kernel/`、`/src/techpack/`，`src/README.md` 已入库说明。
2. 源码快照走 **Release 资源**而非 git 历史（378.6 MB；排除 `.git` 后会明显变小）。
3. 缓存键内容寻址（`src-ack-<pin>-v1` / `ccache-v1` / `out-v1`），不再每轮重下重传。
4. **bring-up 配置必须用真实符号**：`CONFIG_LTO_NONE=y`（LTO 是 choice），`# CONFIG_KASAN is not set`（menuconfig），否则静默无效。
5. 稳定构建配方（已验证）：`gki_defconfig` + `config/bringup-lite.config`，`LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-`，clang 14，`-j4`，约 18 分钟。

## 下一步（按序）

1. **把 `9360e0b0` 写入仓库变量 `ACK_SHA`**（固定定版；缓存键随之变为 `src-ack-9360e0b0...-v1`）。
2. **关闭 R10**：确认 CAF `audio-kernel` / `camera-kernel` / `video-driver` 的 5.10 分支名（`display-drivers` 已确认）。
3. **cepheus DTS 移植**：从 5.4 树 `arch/arm64/boot/dts/xiaomi/{base,cepheus,common}` 取，改 5.10 binding；新增 `arch/arm64/configs/vendor/cepheus.config`；目标 `TARGETS="Image dtbs"`。
4. 重打一次 bootstrap 快照（排除 `.git`，核对 `du -sh` 与条目数）。
5. S3 前移除 `config/bringup-lite.config`（D009 复核触发）。

## 阻塞项

| 编号 | 内容 | 影响 | 需要谁 |
|---|---|---|---|
| Q002-刷机 | 设备有、免授权 9008 可用，暂不刷机 | 实机首启验收推迟 | 用户择机 |
| Q005 | 相机 UAPI 策略未定 | 影响 techpack/camera 移植方向 | 用户（S2 前） |
| R10 | CAF audio/camera/video 5.10 分支名未确认 | techpack 三件套未拉取 | CI 上继续探测 |

## 本机能力边界

- 能：git（GCM 缓存凭据）、`bash -n`、脚本 `--check`、YAML 校验、Actions API（触发/取消/取日志/取 artifact/读 annotation）。
- 不能：本机编译内核；稳定拉/推约 200 MB 级 git pack（多次 `curl 18` / `HTTP 504`）。
- 教训：dispatch 前必须确认远端 commit 已同步；失败 run 日志可能是空包（runner 死亡），此时用 check-run **annotations** 才能拿到失败原因。
