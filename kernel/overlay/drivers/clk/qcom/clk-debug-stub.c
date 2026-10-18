// SPDX-License-Identifier: GPL-2.0-only
/*
 * cepheus bring-up 适配层：clk debug 钩子的空实现
 *
 * 见 clk-debug.h 的说明与 memory/decisions/D015-framework-override.md：
 * CAF 的 clk 框架引用了这两个 debug 钩子，但完整实现牵涉大量 vendor 依赖，
 * bring-up 阶段用空实现即可（仅影响 debugfs 时钟视图）。
 */

#include <linux/clk-provider.h>
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
