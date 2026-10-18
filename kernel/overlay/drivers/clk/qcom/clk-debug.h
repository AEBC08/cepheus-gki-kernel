/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * cepheus bring-up 适配层：clk debug 钩子的最小实现
 *
 * 背景（memory/decisions/D015-framework-override.md）：
 *   CAF 的 clk 框架（clk-alpha-pll.c / clk-rcg2.c / clk-branch.c /
 *   clk-regmap-divider.c）在 clk_ops.debug_init 与 measure 通路里引用了
 *   clk-debug.h 的两个符号：
 *       clk_common_debug_init(hw, dentry)
 *       clk_debug_measure_add(hw, dentry)
 *
 *   CAF 的完整实现（clk-debug.c）还依赖 <linux/clk/qcom.h>、gdsc-debug.h 等
 *   一串 vendor 头，对 bring-up 阶段没有价值（只是 debugfs 时钟视图）。
 *
 *   因此这里只提供**空实现**，让框架能编译链接：
 *   - 不影响时钟功能本身（debug_init 仅在 debugfs 初始化时被调用）
 *   - 代价：/sys/kernel/debug/clk 下没有 CAF 的扩展测量视图
 *
 *   若后续需要真正的 debug 视图，再整体移植 CAF 的 clk-debug.c 及其依赖。
 */

#ifndef __QCOM_CLK_DEBUG_CEPHESUS_H
#define __QCOM_CLK_DEBUG_CEPHESUS_H

struct clk_hw;
struct dentry;

void clk_common_debug_init(struct clk_hw *hw, struct dentry *dentry);
void clk_debug_measure_add(struct clk_hw *hw, struct dentry *dentry);

#endif /* __QCOM_CLK_DEBUG_CEPHESUS_H */
