# F016 — B4（techpack/display）：源码可进树，但不能内建；模块化路线需要先解决 CONFIG 撞名

- **日期**：2026-10-18
- **对应 run**：#26（首次接入 + 探针）、#27（取证）、#28（模块化构建探针）
- **结论**：契约第 8 条判定为**"与 ACK 核心不兼容"**，给出量化证据与替代方案（D016）。B4 未产出 `.o`/`.ko`。

## 1. 已经做到的

| 项 | 状态 | 证据 |
|---|---|---|
| display 源码由构建流程引入 | ✅ | run #26/#27/#28 的 prepare 日志：`接入 display techpack：src/techpack/display-drivers -> src/kernel/drivers/techpack/display` |
| 源码版本可追溯 | ✅ | `display techpack HEAD = ecf501e10535cf05d1a6a7daaaa6d24e7d62527c`（与 F009 的 pin 一致） |
| 分支来自仓库变量 | ✅ | GitHub Actions variable `TECH_BRANCH_DISPLAY = display-kernel.lnx.5.10.r8-rel`（本次新建） |
| 构建入口已写成 patch | ✅ | `kernel/patches/0006`，本地 `git apply --check` exit=0 |

## 2. 为什么不能内建（run #27 的 CI 取证原文）

```
== 所有 obj- 规则（前 80 行）==
src/kernel/drivers/techpack/display/Kbuild:12:obj-$(CONFIG_DRM_MSM) += msm/
src/kernel/drivers/techpack/display/msm/Kbuild:97:obj-m += msm_drm.o

== msm/{sde,dsi,dp} 里构建规则文件数 ==
  msm        : 2
  msm/sde    : 0
  msm/dsi    : 0
  msm/dp     : 0
```

三条硬结论：

1. **它是外部模块布局**：`msm/Kbuild` 用 `obj-m`，顶层 `Makefile` 是 `$(MAKE) -C $(KERNEL_SRC) M=$(M) modules`。
2. **`msm/{sde,dsi,dp}` 没有任何 Kbuild/Makefile**：源码清单全部写死在 `msm/Kbuild` 里，按 `CONFIG_*` 罗列。
   所以无法"只编一个文件"来探针，必须整体按模块走。
3. **开关撞名**：入口是 `obj-$(CONFIG_DRM_MSM)`，而 ACK 的 `gki_defconfig` 里是
   `# CONFIG_DRM_MSM is not set`，且 ACK 的 `drivers/gpu/drm/msm/` 是**另一套**同名驱动。
   打通它就得二选一，等于改基线技术路线（契约边界 6 的触发条件）。

## 3. 我第一次的失误（记录以免重犯）

第一版把开关写成 `CONFIG_DISPLAY_BUILD` 并塞进 `config/bringup-display.config`。
run #26 的 `kernel.config` 里 `DISPLAY_BUILD` **0 处出现**——因为该符号不在任何 Kconfig 里，
`merge_config.sh` 直接丢弃了它。→ **教训：往 fragment 里加符号之前，先在 Kconfig 里确认它存在。**

## 4. 模块化探针（run #28）的结果

```
return code = 0
error 总数 = 0
产出的 .ko = （空）
```

"成功但零产物"的根因就是 §2 的第 3 条：`obj-$(CONFIG_DRM_MSM) += msm/` 在 `CONFIG_DRM_MSM` 未开时展开为空，
kbuild 认为"这个模块没有东西要编"。**这不是"能编过"，而是"根本没编"。**
如实记：**B4 未产出 `.o`/`.ko`，未达到契约第 8 条的首选路径。**

## 5. 替代方案（D016）

1. 模块化构建时用**独立的 .config**（在 out/ 里叠加 display 的 `config/lahainadisp.conf`），
   绕开 ACK 内建 `.config` 的 `DRM_MSM` 撞名；
2. 需要解决 GKI 2.0 的 KMI 约束：`msm_drm.ko` 只能用 `Module.symvers` 导出的符号，
   而 CAF display 用了大量 vendor 内部符号（`sde_power_handle`、`msm_ion` 等）——这是 S2 的工作量；
3. 在那之前，B4 的状态是"源码已进树 + 入口已就绪 + 阻塞点已量化"，不是"已完成"。

## 6. 附带的正面结果

- run #26/#27/#28 的 `Image` 构建**全部 success、error=0**，说明 patch 0005/0006 与 workflow 改动
  都没有破坏基线；`with_display_techpack` 默认 0，基线完全不受影响。
- run #28：`Image` 30,341,632 B、`System.map` 6,333,523 B、`kernel.config` 183,086 B。
