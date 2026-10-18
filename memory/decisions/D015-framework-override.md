# D015 — 允许"有意的框架级覆盖"（vendor 框架前移）

- **状态**：已定
- **日期**：2026-10-18
- **决策者**：PI-Desktop（依 B1 实测，见 F011）

## 背景

D010 定下的原则是：**overlay 只放新增文件，修改 ACK 既有文件走 patch**，目的是"不覆盖上游、保住上游更新"。

但 B1 实测（F011）暴露出另一类情况：CAF 对**内核框架文件本身**做了扩展，例如

- `drivers/clk/qcom/vdd-level.h`：ACK 5.10 **完全没有**此文件（CAF 私有：`struct clk_vdd_class`、`DEFINE_VDD_REGULATORS`）
- `drivers/clk/qcom/clk-alpha-pll.[ch]`：CAF 版含 **Trion PLL** 与 vdd 支持，ACK 上游版没有

这类不是"驱动"，而是**被许多驱动依赖的框架**。用 patch 一行行往上加是不现实的（会变成重写上游文件），
正确做法是**整文件替换为 CAF 版本**。

## 决策

允许对 vendor 框架文件做**有意的、逐文件登记的整文件覆盖**，并附加三条硬性约束：

1. **必须在决策/findings 中登记**：覆盖了哪个文件、为什么、影响面是什么。不允许"顺手覆盖"。
2. **必须锁定影响面**：在 `config/bringup-cepheus.config` 中**只启用本机型需要的驱动**
   （例如 clk 只留 SM8150 系，关掉其它 SoC 的 clk 驱动），避免 CAF 框架替换波及别的平台。
3. **必须是可回溯的**：commit 信息写清"这是框架级替换（D015）"，与 D010 的 patch 类改动区分开。

## 第一批适用对象（B1a，实际执行清单）

实测依赖闭包后，B1a 覆盖/新增了 **17 个文件**（均在 `drivers/clk/qcom/`）：

| 文件 | 类型 | 与 ACK 5.10 的差异 |
|---|---|---|
| `clk-regmap.h` | **覆盖** | +54/−7（`struct clk_regmap` 增加 `dependent_hw`/`vdd_data`/`ops`/`flags` 等） |
| `clk-regmap.c` | **覆盖** | +227/−2（vdd 运行时投票、ops 分发） |
| `clk-regmap-divider.h` | **覆盖** | +7/−5（增加 `flags`/`table`） |
| `clk-regmap-divider.c` | **覆盖** | debug 钩子 |
| `clk-rcg.h` | **覆盖** | +14/−2（`current_freq`/`enable_safe_config`/`flags`） |
| `clk-rcg2.c` | **覆盖** | +725/−109 |
| `clk-branch.h` | **覆盖** | +4/−2（新增两个 ops 声明） |
| `clk-branch.c` | **覆盖** | 对应实现 |
| `clk-alpha-pll.h` | **覆盖** | +92/−28（Trion PLL 声明） |
| `clk-alpha-pll.c` | **覆盖** | **+3702/−506**（Trion PLL、vdd 支持、debug 钩子） |
| `common.h` | **覆盖** | +26/−3 |
| `common.c` | **覆盖** | +254/−3 |
| `vdd-class.h` / `vdd-class.c` | **新增**（ACK 无） | 263 + 77 行：电压等级投票核心 |
| `vdd-level.h` | **新增**（ACK 无） | 31 行：`vdd_levels` 枚举与 corner 表 |
| `clk-debug.h` / `clk-debug-stub.c` | **新增（我们写的）** | 仅提供 `clk_common_debug_init`、`clk_debug_measure_add` 空实现；见下方说明 |

合计约 **+5100/−660 行**。

### 关于 debug 钩子的取舍

CAF 的 `clk-debug.c`（622 行）还依赖 `<linux/clk/qcom.h>`、`gdsc-debug.h` 等 vendor 头，
对 bring-up 无价值（只是 debugfs 时钟视图）。因此我们**不移植它**，改为自己写 2 个空实现
（`clk-debug.h` + `clk-debug-stub.c`），并在 `kernel/patches/0003` 里加入 `clk-qcom-y`。

代价：`/sys/kernel/debug/clk` 下没有 CAF 的扩展测量视图。需要时再整体移植。

### 影响面锁定（D015 约束 2）

- `gki_defconfig` 本身不启用任何 qcom clk 驱动，所以只有我们在
  `config/bringup-cepheus.config` 里显式列出的 SM8150 系会被编译；
- 另在该 config 里显式 `# CONFIG_SM_*_8250 is not set`，把"只编译本机型"写成可审计的事实。

## 风险与控制

- **风险**：`clk-alpha-pll.[ch]` 被所有 qcom clk 驱动共享；替换后其它 SoC 的 clk 驱动可能编不过。
- **控制**：`gki_defconfig` 默认会启用一批 qcom clk 驱动，我们在 `bringup-cepheus.config` 里显式关闭
  非 8150 的（`# CONFIG_SM_*_8250 is not set` 等），让编译面收敛到本机型。
- **复核触发**：若替换后错误集中在"其它 SoC 的驱动"，说明影响面没锁住，需回头补 config；
  若错误集中在 clk-alpha-pll 自身（API 结构差异过大），则考虑改用"只把 Trion PLL 与 vdd 支持以 patch 追加"的方式。

## 与 D010 的关系

D010 仍然有效：**驱动/设备树类修改**继续走 patch；本决策只针对**框架文件**，且必须登记 + 锁影响面。
两者不冲突：判据是"这个文件是不是被多平台共享的框架"。
