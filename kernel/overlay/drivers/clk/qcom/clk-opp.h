/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * cepheus bring-up 适配层：clk OPP 表的空实现
 *
 * 背景（memory/decisions/D015-framework-override.md）：
 *   CAF 的 common.c 在注册时钟时会调用 clk_hw_populate_clock_opp_table()
 *   为每个 clock 生成 OPP 表（供 dev_pm_opp_set_rate() 之类的路径使用）。
 *   完整实现是 CAF 的 drivers/clk/qcom/clk-opp.c（178 行）。
 *
 *   bring-up 阶段我们**不做**时钟级 OPP 表填充：
 *   - 启动路径不依赖它（频率由 clk_set_rate + DT 里的 freq_tbl 决定）；
 *   - 若后续 devfreq/display 需要 OPP 驱动时钟，再整体移植 clk-opp.c。
 *
 *   代价：依赖 dev_pm_opp_set_rate() 的时钟调频路径会失败（打印 -ENODEV）。
 */

#ifndef __QCOM_CLK_OPP_CEPHESUS_H
#define __QCOM_CLK_OPP_CEPHESUS_H

struct clk_hw;
struct device_node;

int clk_hw_populate_clock_opp_table(struct device_node *np, struct clk_hw *hw);

#endif /* __QCOM_CLK_OPP_CEPHESUS_H */
