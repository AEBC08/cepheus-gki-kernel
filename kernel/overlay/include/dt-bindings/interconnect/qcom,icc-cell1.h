/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * cepheus B3 适配层（D010 patch 类改动，见 memory/findings/F015）：
 *   CAF 的 interconnect ID 空间  →  ACK 5.10 的 "cell=1 索引" 语义
 *
 * 背景：
 *   - 我们的 DT 沿用 CAF 的 ID（`qcom,sm8150-cepheus.h`，149 个宏，全局编号）；
 *   - ACK 的 qcom interconnect 驱动（drivers/interconnect/qcom/icc-rpmh.c）用
 *     of_icc_xlate_onecell()，即 `#interconnect-cells = <1>` 时，cell 是
 *     **该 provider 内部节点数组的下标**，并且要打上 provider 号（N）的标签：
 *         node = data->nodes[args[0] + provider->first_node_id]
 *     实际取值必须落在这个 provider 已经注册的节点区间内。
 *   - 两者对不上，因此这里按 provider 提供「CAF ID → ACK 索引」的字面映射。
 *
 * 用法：
 *   interconnect 属性里每个 phandle 后面追加一个 cell，值为按 provider 展开的宏：
 *     interconnects = <&gem_noc CE_GEM_NOC(MASTER_APPSS_PROC)
 *                      &gem_noc CE_GEM_NOC(SLAVE_LLCC)>;
 *
 * 索引从 0 起（provider 的第一个节点），只列本项目 DT 实际用到的节点；
 * 未列出的宏故意不定义，让 dtc 直接报错，避免静默错映射。
 */

#ifndef __DT_BINDINGS_INTERCONNECT_QCOM_ICC_CELL1_H
#define __DT_BINDINGS_INTERCONNECT_QCOM_ICC_CELL1_H

/*
 * gem_noc（ACK: drivers/interconnect/qcom/sm8150.h gem_noc_nodes[] 顺序）
 * ACK 的 gem_noc 里 master/slave 编号本就连号，CAF 的 gem_noc 段亦然，
 * 所以这里是恒等映射（保留宏是为了统一写法与将来可调）。
 */
#define CE_GEM_NOC(x)		(x)

/*
 * mc_virt：CAF 的 MC_VIRT 段不是从 0 起，ACK 的 mc_virt_nodes[] 只有两个节点
 * （MASTER_LLCC=0, SLAVE_EBI1=1）。
 */
#define CE_MC_VIRT_MASTER_LLCC	0
#define CE_MC_VIRT_SLAVE_EBI1	1

#endif
