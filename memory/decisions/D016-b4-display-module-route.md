# D016 — B4（techpack/display）的接入结论：不能"直接编进内核"，改走模块化路线

- **状态**：已定
- **日期**：2026-10-18
- **依据**：`memory/findings/F016`（run #26/#27 实测）

## 背景

契约第 8 条要求：B4 必须让 `techpack/display` 由构建流程引入**并参与编译**（有 `.o` 产出或 System.map 符号），
若判定与 ACK 核心不兼容，须给量化证据与替代方案决策，而不是无限期挂起。

## 实测事实（run #27 的 CI 取证，非推测）

1. display 源码已成功进入内核树：`src/kernel/drivers/techpack/display`（HEAD `ecf501e1…`，与 F009 的 pin 一致）。
2. 该树共有 11 个构建文件，但 **`msm/{sde,dsi,dp}` 三个目录里 0 个 Makefile/Kbuild**；
   唯一两处 `obj-` 规则是：
   - `Kbuild: obj-$(CONFIG_DRM_MSM) += msm/`
   - `msm/Kbuild: obj-m += msm_drm.o`
3. `msm/Kbuild` 用 **`obj-m`**，即设计成**可加载模块**（外部模块布局：顶层 `Makefile` 是
   `$(MAKE) -C $(KERNEL_SRC) M=$(M) modules`）。
4. 我们的 `CONFIG_DISPLAY_BUILD` 不在任何 Kconfig 里，被 `merge_config` 直接丢弃
   （run #26/#27 的 `kernel.config` 里 0 处出现）——这是我第一版的失误，已记录。
5. `CONFIG_DRM_MSM` 被 `gki_defconfig` 显式关闭（`# CONFIG_DRM_MSM is not set`）。
   即便强行打开，ACK 的 `drivers/gpu/drm/msm` 与 CAF 的 `msm/` 是**同名的两套不同实现**，
   会撞在同一个配置符号上。

## 决策

**放弃"把 display 编译进 Image"这条路**，改为**模块化接入**：

1. 把 display 作为**外部模块**构建：`make -C <kernel> M=techpack/display modules DISPLAY_ROOT=...`，
   产物 `msm_drm.ko`（可能还有依赖模块）。这与 D003 的模块策略一致（模块放 `/vendor/lib/modules`）。
2. 需要的配置项从"内核内建"改为"导出给模块用"：`CONFIG_DRM=y`（或 m）、`CONFIG_SYNC_FILE=y` 等，
   而 display 自己的 `CONFIG_DRM_MSM*` 由模块构建时的 `.conf` 片段提供，不进入内核 `.config`
   的冲突面。
3. 因此本轮把 B4 的验收锚点定为：**构建流程能产出 display 的 `.o`/`.ko`**（模块化构建通过），
   而不是"符号进 `System.map`"。这是契约第 8 条允许的替代方案，且给出了量化证据。
4. `kernel/patches/0006` 的 `obj-$(CONFIG_DISPLAY_BUILD) += techpack/display/` 这一行**保留但无用**
   （符号不在 Kconfig 里，永不生效），它是"源码进树"的锚点，不构成对基线的影响；
   `config/bringup-display.config` 同样保留为**文档性片段**，并在文件头注明"不参与内核内建"。

## 影响与后续

- **不影响**已收口的 B1a/B1/B2/B3 与 5.4 基线：`with_display_techpack` 默认 0，patch 0006 的开关永不生效。
- **新增工作量**：display 模块化构建还缺一个 `display` 依赖的 vendor 头文件路径（`include/uapi/display`）
  与 `msm_drm.ko` 的 KMI 导出问题（GKI 2.0 要求模块只用 `Module.symvers` 里的符号）。
  这属于 S2 的工作量，不在本次"驱动栈分阶段适配"的 B4 探针范围内。
- **仍然如实标注**：本次没有产出 `msm_drm.ko`，只证明了"不能内建 + 为何不能内建 + 正确的替代路线"。
  这一点已在 `STATE.md` 的"下一步"里写明，不会伪装成已完成。
