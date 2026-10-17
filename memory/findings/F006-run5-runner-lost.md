# F006 — `kernel-build` run #5 分析（runner 失联 + gki_defconfig 的重量级选项）

- **日期**：2026-10-18
- **方法**：Actions REST API（run / jobs / steps / check-run annotations）+ 直接读取 ACK `android12-5.10` 的 `gki_defconfig`、`arch/Kconfig`、`lib/Kconfig.kasan`。以下均为**已验证事实**。

## 1. run #5 结论

**不是编译错误，是 runner 失联。**

| 项 | 值 |
|---|---|
| commit | `4499f8b`（含 `config/bringup-no-lto.config`） |
| 构建步骤 | 17:46:27 UTC 开始，**无结束时间** |
| job 结束 | 18:51:45 UTC（构建持续约 65 分钟） |
| 注释 | `The hosted runner lost communication with the server...` |
| 日志 | `GET /actions/runs/.../logs` 返回 **22 字节**（空包），runner 死亡导致日志未上传 |

步骤耗时（关键旁证）：`恢复源码树缓存` 仅 4 秒、`拉取源码` 0 秒 → 缓存命中或跳过了 clone；随后构建阶段长时间无进展直到失联。

## 2. 为什么"关 LTO"没生效

ACK `android12-5.10` 的 `arch/arm64/configs/gki_defconfig` 实际打开：

```
CONFIG_LTO_CLANG_FULL=y     ← full LTO（不是 CONFIG_LTO_CLANG）
CONFIG_CFI_CLANG=y
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_KASAN=y              ← 内存检查，编译时间/内存成倍
CONFIG_KASAN_HW_TAGS=y
```

`arch/Kconfig` 里 LTO 是 **choice**（`default LTO_NONE`，候选 `LTO_NONE` / `LTO_CLANG_FULL` / `LTO_CLANG_THIN`），
`CONFIG_LTO`、`CONFIG_LTO_CLANG` 只是被 `select` 的隐藏符号。

因此 fragment 里写 `# CONFIG_LTO_CLANG is not set` / `# CONFIG_LTO is not set` **完全无效**，必须写 `CONFIG_LTO_NONE=y`。
`CONFIG_KASAN` 是 `menuconfig`，`# CONFIG_KASAN is not set` 才有效。

→ 结论：run #5 实际上"仍然做了 full LTO，并且额外背着 KASAN + DWARF4"，比 run #2 更重，这就解释了 65 分钟仍不结束。

## 3. 关于源码快照 379 MB 的疑问

`ack-5.10-9360e0b02a7f.tar.zst` = 378.6 MB。**这个数字合理，但里面掺了不该有的东西**：

打包命令是 `tar -C src -cf kernel techpack`，而 `src/kernel` 是 git 克隆出来的目录，**包含 `.git`**（浅克隆的 pack 文件，压缩率极低）。所以 378.6 MB ≈ 源码压缩后（约 150–200 MB）+ `.git` 对象（约 180–220 MB）。

**待修正**：打包时排除 `.git`，并输出 `du -sh` 与 `tar -tf | wc -l` 以便核对（已在下一次 bootstrap 中加上）。
这也解释了为什么"文件数 71074、名字清单 2.6 MB"，与真实源码规模一致——快照并不缺内容。

## 4. 后续动作（已落到代码）

- 新增 `config/bringup-lite.config`：`CONFIG_LTO_NONE=y` + 关 CFI/KASAN/DEBUG_INFO（D009）
- `kernel-build` 默认 `device_configs` 指向该文件
- 快照打包排除 `.git` 并打印 `du -sh` / 文件数
