# D003 — 模块化形态与 KMI 策略

- **状态**：已定（Q004 待用户最终确认，默认为本方案）
- **日期**：2026-10-17
- **决策者**：PI-Desktop（提案）

## 背景

"GKI" 有两种含义，必须明确我们选哪一种：

1. **严格 GKI 2.0**：GKI `Image` 只含核心 + 一份冻结的 KMI 符号表；所有 vendor 驱动作为 `.ko` 编译，**只允许使用 KMI 白名单符号**，符号表变更即 ABI 断裂。
2. **GKI 血统（自洽）**：底板沿用 ACK，驱动以模块或内置方式编入，**允许扩充自有符号表**，不追求 Google 的 ABI 认证。

另外，cepheus 的启动链是 2019 年（Android 9 世代）的布局：**没有 `vendor_boot`、没有 `vendor_dlkm` 分区**（retrofit dynamic partitions 只带来 system/vendor/product 等逻辑分区，bootloader 不认识 `vendor_boot`）。GKI 2.0 的原生模块加载流程依赖 `vendor_boot` 里的 ramdisk 与模块列表。

已验证的参照：5.4 前移树采用**单体编译 + 传统 boot.img**（`build_kernel.sh` 产出 `kernel` / `kernel_dtb` / `dtbo.img`，defconfig 全 `=y`，`CONFIG_QCOM_KGSL=y`），说明"不走 vendor_boot 也能上 5.x"这条路是通的。

## 决策

1. **形态目标**：GKI 2.0 结构（`Image` + `.ko`），但**不追求 Google KMI 认证**；维护自有符号白名单文件 `android/abi_gki_aarch64_cepheus`，允许为 vendor 驱动追加符号。
2. **分两步走**：
   - **S1：先单体（monolithic）跑通**——所有驱动内置，优先解决"能不能开机"。避免一上手就被 KMI 符号缺口拖死。
   - **S2：再模块化**——把 techpack display/camera/audio/video、qcacld、kgsl、dataipa 等拆为 `.ko`，验证"换 GKI Image 而 vendor 模块不变"。
3. **模块落地路径（无 `vendor_boot` 时）**：`.ko` 放 `/vendor/lib/modules/`，由 vendor `init` 通过 `modprobe` 加载，并补 SELinux label（`vendor_file`）。**不使用** super 里的伪 `vendor_dlkm`（除非 S2 证明必要）。
4. **模块签名**：自建内核场景下关闭强制校验（`CONFIG_MODULE_SIG_FORCE=n`）；若 ROM 侧 init 校验模块列表，则同步裁剪。
5. **配置组织**：`gki_defconfig`（底板）+ `arch/arm64/configs/vendor/cepheus.config`（机型片段），用 `scripts/kconfig/merge_config.sh` 合并，禁止手改 `.config`。

## 理由

- **判断（未验证）**：单体先行可以把"驱动前移正确性"和"模块 ABI 正确性"两个问题解耦；5.4 前移树的成功先例正是单体形态。
- **已验证**：无 `vendor_boot` 分区，因此 GKI 官方的模块加载链不可直接用，必须走 `/vendor/lib/modules`。
- **判断（未验证）**：KMI 白名单在机型移植阶段会成为持续摩擦源（每次加驱动都要改 symlist），先不设约束能显著提速；模块化的收益（换 Image 不重编 vendor 驱动）在 S2 才需要。

## 备选方案与否决理由

- **一开始就严格 KMI**：否决。首启阶段缺口不可预测，容易陷入"改符号表 → 破坏 ABI → 再修"的循环。
- **纯单体、永不模块化**：否决。那样只是"版本更高的非 GKI 内核"，失去项目意义（无法跟进新 LTS 而不重编驱动）。
- **用 super 伪造 `vendor_dlkm`**：暂缓。init 通过 `/dev/block/mapper` 挂载再加载模块可行，但增加 SELinux 与 first-stage init 复杂度；S2 再评估。

## 影响与后续

- S2 必须产出：模块清单、加载顺序、symlist 文件、以及"同一 Image 配 4.14 与 5.10 双 boot 可切换"的验证记录。
- 复核触发：若 S1 单体形态下 `Image` 体积超过 boot 分区上限（cepheus boot 分区约 64 MB，需实测），则提前进入模块化。
