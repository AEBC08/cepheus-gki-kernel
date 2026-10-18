// SPDX-License-Identifier: GPL-2.0-only
/*
 * cepheus bring-up 适配层：clk OPP 表的空实现
 *
 * 见 clk-opp.h 的说明与 memory/decisions/D015-framework-override.md。
 * 返回 0（成功但不建表），避免调用方因 -ENODEV 中断时钟注册流程。
 */

#include <linux/errno.h>
#include <linux/of.h>
#include <linux/types.h>

#include "clk-opp.h"

int clk_hw_populate_clock_opp_table(struct device_node *np, struct clk_hw *hw)
{
	/* bring-up: 不建立 per-clock OPP 表（见 clk-opp.h 的取舍说明） */
	return 0;
}
