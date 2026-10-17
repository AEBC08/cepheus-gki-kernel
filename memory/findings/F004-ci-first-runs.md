# F004 — 源码定版与首次 CI 运行记录

- **日期**：2026-10-17
- **方法**：GitHub Actions（`AEBC08/cepheus-gki-kernel`）+ Actions REST API + artifact/log 下载。以下除标注外均为**已验证事实**。

## 1. 仓库与流水线落地

| 项 | 值 |
|---|---|
| 仓库 | `https://github.com/AEBC08/cepheus-gki-kernel`（**公开**，默认分支 `main`） |
| 提交身份 | `AEBC08 <743727279@qq.com>`（仓库级配置） |
| 首次推送 | `0e8db63`（22 文件） |
| 凭据 | 本机 Git Credential Manager **已有缓存凭据**（username=`AEBC08`，token 未在日志/文件中出现） |
| workflows | `bootstrap-sources` (id 387749275)、`kernel-build` (id 387749276)，均 `active` |

> 说明：此前判断"本机无凭据"有误——我只查了 `credential.helper` 的 **global** 作用域，而 Git for Windows 把它写在 **system**（`D:/Git/etc/gitconfig` → `manager`）。该误判已修正。

## 2. `bootstrap-sources` run #1：**成功**

8 个步骤全部 success（Set up / Checkout / 释放磁盘 / 准备缓存 / 恢复源码缓存 / 拉取源码 / 校验源码树 / 生成文件清单 / 上传元数据）。

**产物 `source-metadata`** 中 `src/techpack/PINS.txt`（已验证内容）：

```
ack  https://github.com/aosp-mirror/kernel_common  android12-5.10  9360e0b02a7f1595661f6a087ef4c439594475a7
techpack/display-drivers  https://git.codelinaro.org/clo/la/platform/vendor/opensource/display-drivers
                          display-kernel.lnx.5.10.r8-rel  ecf501e10535cf05d1a6a7daaaa6d24e7d62527c
```

**`kernel-files.txt`**：ACK 树共 **71074** 个文件；`arch/arm64/configs/gki_defconfig` 存在；`arch/arm64/boot/dts/qcom/` 94 项；`techpack/` 0 项（符合预期——techpack 是独立 staging 目录，尚未 in-tree）。

**techpack 现状**：`display-drivers` 已取到（PINS 有记录）；`audio-kernel` / `camera-kernel` / `video-driver` 因分支名未确认被跳过 → **R10 仍未关闭**。

## 3. `kernel-build` run #1：**失败（已定位并修复）**

失败步骤 `构建`，关键报错：

```
src/kernel/arch/arm64/include/asm/atomic_lse.h:364: error: unknown register name 'x0' in asm
fatal error: too many errors emitted, stopping now [-ferror-limit=]
```

**根因**：Linux 5.10 的顶层 Makefile 由 `CROSS_COMPILE` 推导 clang 的 `--target` 三元组。只传 `LLVM=1 LLVM_IAS=1` 时 clang 使用宿主机 `x86_64` 目标，arm64 内联汇编中的 `x0/x1/x2` 寄存器名无法识别。

**修复**（commit `a7a1cf4`）：
- `scripts/build-kernel.sh`：`USE_LLVM=1` 时同时传 `CROSS_COMPILE=aarch64-linux-gnu-`
- `kernel-build.yml`：安装 `gcc-aarch64-linux-gnu` / `binutils-aarch64-linux-gnu` 作为兜底

## 4. 流程性发现（对后续有用）

1. **`kernel-build` 不能假定自己在内核仓库里跑**：原设计 checkout 即内核树，但当前 CI 入口是控制仓库、`src/kernel` 不存在，会在 `check_kernel_tree` 直接失败。已改成复用 `bootstrap-sources` 的源码缓存（同 `src-ack-` key 前缀），缓存未命中时调用 `fetch-sources.sh`（commit `cae5081`）。
2. **artifact 会保留相对路径**：`upload-artifact` 未剥离 `src/techpack/` 前缀，下载后需按 `src/techpack/PINS.txt` 取。
3. **日志文件名含中文**：解压后按 `9_构建.txt` 之类的名字取文件，在 PowerShell 下用 `-like '9_*'` 或直接读 `0_<job>.txt` 全量日志更稳。
4. Actions 提示 `actions/cache@v4`、`actions/checkout@v4` 仍指向 Node 20，已被强制跑在 Node 24（仅警告，不影响）。
