# F014 — B2（pinctrl）：判定「复用上游」，只开配置

- **日期**：2026-10-18
- **对应 run**：`kernel-build` **#23**（head `cadc2dc`）
- **结论**：B2 判定为**复用 ACK 上游驱动**（不移植），依据是 of_match 与驱动数据表的对照；构建与符号断言均通过

## 1. of_match 对照证据

| 侧 | 内容 |
|---|---|
| 我们的 DT（`sm8150-pinctrl.dtsi:8`） | `compatible = "qcom,sm8150-pinctrl";` |
| ACK `drivers/pinctrl/qcom/pinctrl-sm8150.c` 的 of_match | `{ .compatible = "qcom,sm8150-pinctrl" }` |

**完全一致**，不需要改 DT、不需要移植驱动。

## 2. 驱动数据表完整性（为何可以放心复用）

ACK 上游驱动不是"空壳"，自带完整 SM8150 TLMM 描述：

```
static const struct msm_pinctrl_soc_data sm8150_pinctrl = {
	.pins = sm8150_pins,  .npins = ARRAY_SIZE(sm8150_pins),
	.functions = sm8150_functions, .nfunctions = ARRAY_SIZE(sm8150_functions),
	.groups = sm8150_groups, .ngroups = ARRAY_SIZE(sm8150_groups),
	.tiles = sm8150_tiles, .ntiles = ARRAY_SIZE(sm8150_tiles),
};
```
文件 45,040 B。与 CAF 5.4 的差异属于 pin 命名/function 编号层面，**不影响"能绑定、能编译"**；
DT 里 `tlmm: pinctrl@03000000` 的属性（`reg`、`interrupts`、`gpio-controller`、`#interrupt-cells`）也都在上游驱动的解析范围内。

## 3. run #23 验收数据

- 「构建」步骤 conclusion = **success**；日志 `error:` 计数 = **0**
- artifact `kernel-cepheus-5.10-23`（16.01 MB）：`Image` = 30,214,656 B（28.81 MiB）、`kernel.config`、`System.map`
- 配置断言：`CONFIG_PINCTRL_SM8150=y`；影响面锁定 `# CONFIG_PINCTRL_SM8250 is not set`
- 符号断言（`System.map`）：`sm8150_pinctrl` = 7、`sm8150_pinctrl_probe` = 1、`msm_pinctrl_probe` = 4

## 4. 顺带确认（与 B1 的遗留项相关）

本批次顺手核对了 interconnect 的 Kconfig 依赖链，为 B3 做准备（见 F015）：
`INTERCONNECT_QCOM_RPMH_POSSIBLE` 依赖 `QCOM_RPMH`，与 `CONFIG_QCOM_CLK_RPMH` 同样的坑——
**fragment 里必须显式写 `CONFIG_QCOM_RPMH=y`**，否则 `CONFIG_INTERCONNECT_QCOM_SM8150` 会被 merge_config 丢弃。

## 5. 判定

**B2 达成**：pinctrl 满足「构建成功 / `CONFIG_PINCTRL_SM8150=y` / `System.map` 有符号」，且给出了 of_match 一致的"复用上游"证据（契约第 7 条要求）。
