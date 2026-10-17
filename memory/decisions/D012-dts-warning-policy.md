# D012 — DTS 告警处理策略（修到什么程度为止）

- **状态**：已定
- **日期**：2026-10-18
- **决策者**：PI-Desktop

## 背景

`cepheus-sm8150.dtb` 首次编出时 dtc 报 **31 条**告警（F008 §5）。逐条追下去会产生无边界的工作量，
需要一条明确的分界线：**哪些必须修（会影响运行时行为），哪些明确接受（纯结构性提示）**。

## 决策

### 1. 必须修：语义类告警

凡涉及 **`reg` / `ranges` / `#address-cells` / `#size-cells`** 且指向我们会在 S2 点亮的设备的，
一律修，因为它们直接影响 `of_address_to_resource()`、`platform_get_resource()` 的解析结果。

本轮已修（提交 `1579de0`、`5928390`）：

| 位置 | 问题 | 修法 |
|---|---|---|
| `pm8150b.dtsi` `qcom,qpnp-smb5`、`qpnp,fg` | 声明 `#size-cells = <1>`，子节点 `reg = <0x1000>`（4 B） | 改为 `<0>` |
| `pm8150l.dtsi` `qcom,lcdb@ec00`、`qcom,amoled` | 同上 | 改为 `<0>` |
| `sm8150.dtsi` `glink_adsp: adsp`、`qcom,gpr` | 子节点 `reg = <GPR_DOMAIN_*>`（单 cell 服务 ID），父节点继承 glink 的 `2/1` | 显式声明 `#address-cells = <1> / #size-cells = <0>` |

效果：**31 → 2 条**。`reg_format`、`avoid_default_addr_size`、`spi_bus_reg`、`pci_device_bus_num` 全部归零。

### 2. 明确接受：`base/trusty.dtsi` 的 2 条 `ranges_format`

```
/soc/trusty:ranges: empty "ranges" property but its #address-cells (2) differs from /soc (1)
/soc/trusty:ranges: empty "ranges" property but its #size-cells (2) differs from /soc (1)
```

接受理由：

- `ranges` 是**空属性**，不产生任何地址翻译，因此与 `/soc` 的 1/1 不同**不影响解析**。
- trusty 节点下子设备使用 64 位地址（2/2），若为了消警把它改成 1/1，反而会改变子节点的
  `reg` 解释，**引入真实错误**——为消一条提示性告警去改语义是错的方向。

### 3. 判定准则（后续沿用）

> 告警的出现位置若有我们**会在真机上用到的节点**，就修；否则记录理由并保留。
> 任何"接受"都必须写进本文件或对应 findings，不允许静默忽略。

## 影响与后续

- `make dtbs` 现在稳定通过，仅 2 条已记录理由的提示。
- 若 S2 点亮 trusty 相关功能（如 TEE/qseecom）时发现地址异常，再回头评估这 2 条。
- 复核触发：dtc 升级或我们覆盖 `/soc` 的 cells 时，重新审视 trusty 节点。
