/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * cepheus bring-up 适配层：clk debug 钩子的最小实现
 *
 * 背景（memory/decisions/D015-framework-override.md）：
 *   CAF 的 clk 框架（clk-alpha-pll.c / clk-rcg2.c / clk-branch.c /
 *   clk-regmap-divider.c / common.c）引用了 clk-debug.h 的几个设施：
 *       clk_common_debug_init(hw, dentry)
 *       clk_debug_measure_add(hw, dentry)
 *       clk_debug_print_hw(hw, seq_file)
 *       WARN_CLK(hw, cond, fmt, ...)        宏
 *       clock_debug_output(seq_file, fmt, ...) 宏
 *
 *   CAF 的完整实现（clk-debug.c，622 行）还依赖 <linux/clk/qcom.h>、
 *   gdsc-debug.h 等一串 vendor 头，对 bring-up 阶段没有价值（只是 debugfs
 *   时钟视图）。因此这里只保留**接口与宏**，实现留空。
 *
 *   代价：WARN_CLK 触发的时钟配置告警不会打印细节；/sys/kernel/debug/clk
 *   下没有 CAF 的扩展测量视图。需要时再整体移植 clk-debug.c。
 *
 * 注：宏定义照抄 CAF 原版，保证调用点语义（条件成立时告警）不变。
 */

#ifndef __QCOM_CLK_DEBUG_CEPHESUS_H
#define __QCOM_CLK_DEBUG_CEPHESUS_H

#include <linux/seq_file.h>

struct clk_hw;
struct dentry;

void clk_common_debug_init(struct clk_hw *hw, struct dentry *dentry);
void clk_debug_measure_add(struct clk_hw *hw, struct dentry *dentry);
void clk_debug_print_hw(struct clk_hw *hw, struct seq_file *f);

#define WARN_CLK(hw, cond, fmt, ...) do {				\
	clk_debug_print_hw(hw, NULL);					\
	WARN(cond, "%s: " fmt, clk_hw_get_name(hw), ##__VA_ARGS__);	\
} while (0)

#define clock_debug_output(m, fmt, ...)					\
	do {								\
		if (m)							\
			seq_printf(m, fmt, ##__VA_ARGS__);		\
		else							\
			pr_info(fmt, ##__VA_ARGS__);			\
	} while (0)

#endif /* __QCOM_CLK_DEBUG_CEPHESUS_H */
