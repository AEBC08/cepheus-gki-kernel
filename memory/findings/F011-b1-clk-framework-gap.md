# F011 — B1（时钟批次）实测：需要先移植 CAF 的 clk 框架扩展

- **日期**：2026-10-18
- **方法**：把 5.4 前移树的 camcc/dispcc/npucc/scc-sm8150.c 与 `vdd-level-sm8150.h` 放进 overlay，
  用 kernel/patches/0002 登记到 ACK 的 `drivers/clk/qcom/{Kconfig,Makefile}`，CI 构建（run #16）。

## 1. 结果

构建失败，`error:` 共 60 行（每文件被 `-ferror-limit` 截断），分布：

| 文件 | error 行 |
|---|---|
| `camcc-sm8150.c` | 19 |
| `dispcc-sm8150.c` | 19 |
| `npucc-sm8150.c` | 19 |
| 其它（ferror-limit 提示） | 3 |

`scc-sm8150.c` 未出现在错误里（可能被前面的 ferror-limit 掩盖或未编到）。

## 2. 根因（三类，均属"框架缺件"而非"逻辑错误"）

1. **`DEFINE_VDD_REGULATORS` 宏未定义**
   ```
   camcc-sm8150.c:34:50: error: expected identifier
   camcc-sm8150.c:34:29: error: this function declaration is not a prototype
   camcc-sm8150.c:38:3:  error: use of undeclared identifier 'vdd_mm'
   ```
   该宏与 `struct clk_vdd_class` 在 CAF 的 **`drivers/clk/qcom/vdd-level.h`** 里，
   ACK 5.10 完全没有这个文件（已列出 5.4 树含 `vdd-level.h` + 各 SoC 的 `vdd-level-*.h`）。

2. **Trion PLL ops 不存在**
   ```
   camcc-sm8150.c:168:12: error: use of undeclared identifier 'clk_trion_pll_ops';
                                    did you mean 'clk_alpha_pll_ops'?
   camcc-sm8150.c:199:11: error: use of undeclared identifier 'clk_trion_pll_postdiv_ops'
   ```
   CAF 在 `clk-alpha-pll.[ch]` 里扩展了 Trion PLL 支持，ACK 5.10 的上游版本没有。

3. **`#include <dt-bindings/clock/qcom,camcc-sm8150.h>`**
   已用我们的 `-cepheus` 头策略覆盖（DT 侧已就位），这部分不是错误来源。

## 3. 结论

B1 不能"直接搬驱动"，必须先补 **clk 框架扩展**（一个前置批次，记为 **B1a**）：

- `drivers/clk/qcom/vdd-level.h`（CAF 私有：`clk_vdd_class`、`DEFINE_VDD_REGULATORS`）
- `vdd-level-sm8150.h`（已就位）
- `clk-alpha-pll.[ch]` 的 CAF 版本（Trion PLL + vdd 支持）
- 视需要 `clk-debug.[ch]`（若后续启用 debugcc）

**风险**：`clk-alpha-pll.[ch]` 是被所有 qcom clk 驱动共享的文件；替换为 CAF 版本会影响其它 SoC 的
clk 驱动。缓解方式：我们的内核是机型专用，可在 `config/bringup-cepheus.config` 里**只启用 SM8150
系列 clk 驱动**（关掉其它 SoC），把影响面锁死。

## 4. 下一步（B1a）

1. 导入 `vdd-level.h` + CAF 版 `clk-alpha-pll.c/h` 到 overlay（覆盖 ACK 同名文件 → 属于"vendor 框架前移"，
   需在 commit 中明确说明并记录，区别于 D010 的"不覆盖上游"原则——这是**有意的框架级替换**，
   因此要单独记为 D015 决策）。
2. 在 `config/bringup-cepheus.config` 里只保留 SM8150 系 clk 驱动，关闭其它 SoC。
3. 重跑构建，按错误继续迭代。

## 5. 附带确认

- 5.4 树的 clk 目录文件清单（已实测）：`clk-alpha-pll.c/h`、`clk-branch.c/h`、`clk-debug.c/h`、
  `clk-pll.c/h`、`clk-rcg2.c`、`vdd-level.h` + 各 SoC 的 `vdd-level-*.h`。
