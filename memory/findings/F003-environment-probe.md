# F003 — 本机环境与网络可达性探针

- **日期**：2026-10-17
- **方法**：`Get-CimInstance`、`Get-Volume`、`wsl -l -v`、`docker version`、`Get-Command`、`Invoke-WebRequest -Method Head -TimeoutSec 8`、`git ls-remote`。均为**已验证事实**。

## 1. 硬件/系统

| 项 | 值 |
|---|---|
| OS | Microsoft Windows 11 IoT 企业版 LTSC，build 26300 |
| CPU | Intel Core i5-2430M @ 2.40 GHz（2 核 4 线程，Sandy Bridge） |
| 内存 | 7.9 GB |
| 磁盘 | C: 54.6 GB 可用 / 100 GB；D: 128.9 GB / 233 GB；E: 94.7 GB / 151 GB；F: 31.4 GB / 112.2 GB |

## 2. 构建前置

| 项 | 状态 |
|---|---|
| WSL | **未安装**（`wsl -l -v` 输出为安装提示） |
| Docker | **不可用** |
| git | `D:\Git\cmd\git.exe` ✓ |
| python | `D:\Python\Python313\python.exe` ✓ |
| bash | `D:\Git\bin\bash.exe`（Git Bash）✓ |
| clang / make / adb / fastboot / 7z | **全部缺失** |

结论：**本机无法原生构建 Android 内核**，也无法对真机执行 adb/fastboot 操作（缺 adb/fastboot，但可通过安装 platform-tools 解决）。

## 3. 网络可达性

| 目标 | 结果 |
|---|---|
| `https://github.com` | ✓ 200 |
| `https://git.codelinaro.org` | ✓ 200（CAF 源码可拉） |
| `https://android.googlesource.com` | ✗ 8 s 超时 |
| `https://kernel.googlesource.com` | ✗ 8 s 超时 |
| `git ls-remote https://android.googlesource.com/kernel/common` | ✗ exit 128 |
| `git ls-remote https://github.com/aosp-mirror/kernel_common` | ✓ |

无代理环境变量（`HTTP_PROXY` 等为空）。

补充：`git ls-remote` 对 `git.codelinaro.org` 的大仓库（msm-5.10 等）**极慢**（>7 分钟未完成），改用 GitLab API（`/api/v4/projects/<urlencoded>/repository/branches`）可在秒级返回。已验证 `clo/la/kernel/msm-5.10`、`clo/la/platform/vendor/opensource/display-drivers` 可查；`clo/la/platform/vendor/qcom-opensource/camera-kernel` 路径 404（正确路径待 S1 确认，可能是 `.../vendor/opensource/camera-kernel`）。

## 4. 对策（已体现在 D002 / D004）

1. ACK 一律走 `aosp-mirror/kernel_common`（GitHub 镜像），不依赖 googlesource。
2. CAF 分支探测走 GitLab API，不用 `ls-remote`。
3. 构建必须在 Linux 环境（WSL2 / GitHub Actions / 云主机，Q001）。

## 5. 补充（2026-10-17 晚，已验证）

- `git clone --depth 1 --branch android12-5.10 https://github.com/aosp-mirror/kernel_common` **失败两次**：`RPC failed; curl 18 transfer closed with outstanding read data remaining`（69.9 s 与 1418 s）。加 `http.version=HTTP/1.1`、`http.postBuffer=512MB` 后仍失败（`early EOF` / `fetch-pack: invalid index-pack output`）。
- 期间 GitHub 出现 `504`（`src/ref-5.4` 的 blob:none 克隆亦被波及）。
- 对照：`--filter=blob:none --no-checkout` 的小体积克隆此前可成功 → **本网络对小 pack 可用，对 ~200 MB 单 pack 不可用**。
- CAF 分支探测：`display-drivers` 可查到 `display-kernel.lnx.5.10.r8-rel`（2026-08-27）、`display-kernel.lnx.5.10.2.r1-rel`（2026-08-26）等 17 个含 `5.10` 的分支；但 `audio-kernel` / `camera-kernel` / `video-driver` 用 `search=5.10 / lahaina / kona / wapio` 未得到可靠结果（`video-driver` 仅见 `caf_migration/video-kernel.lahaina.*` 旧分支），`camera-kernel` 查询曾超时。→ R10 仍未关闭。
- 注：`git ls-remote` 对 CAF 大仓库极慢（>7 分钟未完成），**分支探测一律用 GitLab API**（`/api/v4/projects/<urlencoded>/repository/branches`）。
