# F008 — cepheus DTS 导入与 dtbs 打通（5 轮 CI 迭代）

- **日期**：2026-10-18
- **方法**：本地取 CAF 5.4 前移树资产 + CI（Actions）逐轮编译 + 日志/annotation 分析。以下均为**已验证事实**。

## 1. 最终结果

| 项 | 值 |
|---|---|
| run | `kernel-build` #12，commit `7906826` |
| 目标 | `TARGETS="dtbs"`（只编设备树，约 4 分钟） |
| 结论 | ✅ success |
| 关键编译行 | `DTC arch/arm64/boot/dts/xiaomi/cepheus-sm8150.dtb` |
| 产物 | `dts.tar.gz` 1,652,159 B |
| 告警 | 31 条 `reg_format`（见下） |

上游 `qcom/sm8150-mtp.dtb` 同时保持可编 —— 我们的改动没有污染上游。

## 2. 资产导入（本地）

来源：`qaz6750/android_kernel_xiaomi_sm8150@android-5.4.y`（5.4 前移树）。

| 类别 | 数量 | 说明 |
|---|---|---|
| 平台层 dtsi | 34 | `arch/arm64/boot/dts/qcom/sm8150*.dtsi`、`msm-*sm8150*.dtsi` |
| 平台外围 | 5 | `pm8150{,b,l}.dtsi`、`msm-wsa881x.dtsi`、`smb1355.dtsi` |
| 面板 dtsi | 22+ | `qcom/display/` 与 `xiaomi/{cepheus,raphael}/display/` |
| 机型层 | 22 | `xiaomi/{base,common,cepheus}`（含 battery/） |
| 我们新写 | 3 | `cepheus-sm8150.dts`、`xiaomi/Makefile`、`0001-*.patch` |
| dt-bindings | 30 | 见 D011 的隔离规则 |

合计 overlay 文件 120+（含头）。

## 3. CI 迭代序列（每轮的真实报错）

| run | 目标 | 报错（摘要） | 修复 |
|---|---|---|---|
| #7 | `Image dtbs` | 无（dtb 管线验证） | 证明上游 `sm8150-mtp.dtb` 可编 |
| #8 | `dtbs` | `sm8150.dtsi:7: 'dt-bindings/clock/qcom,camcc-sm8150.h' not found` | 导入 CAF 头 |
| #9 | `dtbs` | `xiaomi/sm8150-vidc.dtsi:38` 与 **`qcom/sm8150.dtsi:689`** syntax error | 后者暴露"覆盖了上游头"：7 个同名头改为 `-cepheus` 私有名 |
| #10 | `dtbs` | `xiaomi/pm8150.dtsi:1.1-4` syntax error | 该文件是 14 B 的 `404: Not Found`：curl 批量下载把错误响应写进了文件 |
| #11 | `dtbs` | `pm8150.dtsi:16: 'dt-bindings/input/qcom,qpnp-power-on.h' not found` | 改用本地 CAF 克隆 + `git show` 取，并做递归 BFS 闭合全部头 |
| #12 | `dtbs` | — | ✅ 通过 |

## 4. 三个必须记住的教训

1. **批量下载必须校验内容，而不是"文件存在"**。curl/Invoke-WebRequest 遇到 404 时，`-o` 仍会把 14 字节的 `404: Not Found` 写进目标文件；这类文件在 dtc 里表现为 `1.1-4 syntax error`，极难联想到网络问题。→ 已在 `prepare-kernel.sh` 加 `sanity_check_overlay`（首行 404/`<!DOCTYPE`/`<html` 或体积 <120 B 直接失败）。
2. **不要覆盖上游 dt-bindings**。上游 `qcom/sm8150.dtsi` 会被牵连，且 `icc.h`/`osm-l3.h` 是多平台共用。→ `-cepheus` 私有名。
3. **依赖闭合在本地做，不要用 CI 试错**。递归 BFS 一次收全 30 个头；否则每轮 20 分钟只暴露一个缺失（实测浪费 3 轮）。

## 5. 31 条 `reg_format` 告警的性质与风险

例：

```
pm8150b.dtsi:227.5-20: Warning (reg_format):
/soc/qcom,spmi@c440000/qcom,pm8150b@2/qcom,qpnp-smb5/qcom,chgr@1000:reg:
property has invalid length (4 bytes) (#address-cells == 1, #size-cells == 1)
```

CAF 的写法假设 SPMI 子节点 `#address-cells=1 / #size-cells=0`（`reg = <0x1000>`），
而上游父节点声明 `size-cells=1`（期望 8 字节）。

- 当前影响：仅告警，dtb 可生成。
- **潜在风险**：S2 点亮 charger / FG / typec / vadc 等 SPMI 子设备时，`reg` 长度不符可能导致地址解析异常。
- 处理计划：S2 第一步逐节点校正（或在我们的平台层覆盖父节点的 `#address-cells/#size-cells`），并记录每个改动对应的 dmesg 证据。

## 6. 未完成/待验

- `cepheus-sm8150.dts` 尚未包含 audio overlay 与 `&snd_934x` 的 typec io-channels（S2 音频阶段补）。
- 面板变体（Q009）运行时选择未验证。
- 设备树尚未进真机（用户暂不刷机）。
