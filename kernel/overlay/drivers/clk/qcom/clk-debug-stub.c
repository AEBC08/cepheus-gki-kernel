// SPDX-License-Identifier: GPL-2.0-only
/*
 * cepheus bring-up 适配层：clk debug 钩子的空实现
 *
 * 见 clk-debug.h 的说明与 memory/decisions/D015-framework-override.md：
 * CAF 的 clk 框架引用了这些 debug 钩子，但完整实现牵涉大量 vendor 依赖，
 * bring-up 阶段留空即可（仅影响 debugfs 时钟视图与告警细节）。
 */

#include <linux/clk-provider.h>
#include <linux/seq_file.h>
#include <linux/types.h>

#include "clk-debug.h"

void clk_common_debug_init(struct clk_hw *hw, struct dentry *dentry)
{
	/* bring-up: 不注册 CAF 的扩展 debug 视图 */
}

void clk_debug_measure_add(struct clk_hw *hw, struct dentry *dentry)
{
	/* bring-up: 无测量通路 */
}

void clk_debug_print_hw(struct clk_hw *hw, struct seq_file *f)
{
	/*
	 * CAF 用它打印时钟树细节；bring-up 阶段只打印时钟名，
	 * 保证 WARN_CLK 触发时仍有最小可用的上下文。
	 */
	if (hw)
		clock_debug_output(f, "clk: %s\n", clk_hw_get_name(hw));
}
