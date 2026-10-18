# F013 — B1a（clk 框架前移）+ B1（SM8150 时钟驱动）收口

- **日期**：2026-10-18
- **对应 run**：`kernel-build` **#22**（id 39092292800，head `a9149c9`）
- **结论**：B1a 达成（`error:` = 0）；B1 达成（7 个 `CONFIG_SM_*_8150=y`、4 个控制器符号在 `System.map`、`Image` 30.1 MB）

## 1. 错误收敛过程（实测）

| run | head | `error:` 行数 | 报错位置与根因 | 修复 |
|---|---|---|---|---|
| #17 | `10efcc6` 前 | 21 | `linux/clk/qcom.h` 缺失、`WARN_CLK`/`clock_debug_output` 未声明、`clk_ops.init` 由 void 改 int | 导入 `include/linux/clk/qcom.h`；自写 `clk-debug.h`/`clk-debug-stub.c`；改 13 处 `.init` 回调为 int |
| #18 | — | 1 | `clk-opp.h` 缺失（CAF 私有 OPP 表） | 自写 `clk-opp.h` + `clk-opp-stub.c` |
| #19 | `6c89997` | 15 | rcg2/branch/regmap-divider 的 `.init` 仍是 void | 同批修正签名 |
| #20 | `dbea9a3` | 11 | ACK 自带 `gcc-sm8150.c`/`gpucc-sm8150.c` 用上游 TRION 命名（`clk_alpha_pll_[fixed_|postdiv_]trion_ops`），CAF 版叫 `clk_trion_[fixed_]pll[_postdiv]_ops` | 在覆盖的 `clk-alpha-pll.h` 末尾加 3 个 `#define` 别名（D015 §第二批） |
| #21 | `855a778` | 17 | CAF `dispcc-sm8150.c` 需要 63 个 `DISP_CC_*` ID（`DP_CRYPTO*`/`EDP_*`/`XO_CLK`/`SPDM_BCR`），ACK 头缺 17 个 | 新增 overlay `include/dt-bindings/clock/qcom,dispcc-sm8150.h`（D015 §第二批） |
| **#22** | `a9149c9` | **0** | — | **通过** |

每次修复都用一次真实 CI 构建定位，没有"猜着改"；错误数单调下降 21 → 1 → 15 → 11 → 17 → 0。
其中 #19→#20 有回升，是 `clk-opp` 修好后编译器才走到 gcc/gpucc-sm8150 的编译单元，属正常的"风暴前沿后移"。

## 2. run #22 验收数据（B1a + B1 共用同一次构建）

- 「构建」步骤 conclusion = **success**（run #22，2026-10-18T03:08:30Z 出产物）
- 构建日志 `error:` 计数 = **0**（`11_构建.txt` 全文 grep）
- artifact `kernel-cepheus-5.10-22`（16.76 MB）内含：
  - `Image` = **30,142,976 B（28.75 MiB）** ≥ 20 MB
  - `kernel.config` = 182,682 B
  - `System.map` = 6,295,061 B
  - `build-info.txt`：`overlay_files=150`、`patches=4`、defconfig=`gki_defconfig`、fragments=`bringup-lite,bringup-cepheus`、clang 14.0.0

### 配置断言（`kernel.config`）

| 符号 | 值 |
|---|---|
| `CONFIG_COMMON_CLK_QCOM` | `=y` |
| `CONFIG_QCOM_GDSC` | `=y` |
| `CONFIG_SM_GCC_8150` | `=y` |
| `CONFIG_SM_GPUCC_8150` | `=y` |
| `CONFIG_SM_VIDEOCC_8150` | `=y` |
| `CONFIG_SM_CAMCC_8150` | `=y` |
| `CONFIG_SM_DISPCC_8150` | `=y` |
| `CONFIG_SM_NPUCC_8150` | `=y` |
| `CONFIG_SM_SCC_8150` | `=y` |

影响面锁定生效：`# CONFIG_SM_{GCC,GPUCC,VIDEOCC,DISPCC}_8250 is not set`、`# CONFIG_PINCTRL_SM8250 is not set`。

### 符号断言（`System.map`，grep 计数）

| 符号前缀 | 计数 | 出处 |
|---|---|---|
| `cam_cc_sm8150` | 11 | overlay（CAF 5.4 前移） |
| `disp_cc_sm8150` | 12 | overlay（CAF 5.4 前移） |
| `npu_cc_sm8150` | 12 | overlay（CAF 5.4 前移） |
| `scc_sm8150` | 9 | overlay（CAF 5.4 前移） |
| `gcc_sm8150` | 11 | ACK 上游 |
| `gpucc_sm8150` | 1 | ACK 上游 |
| `video_cc_sm8150` | 11 | ACK 上游 |
| `clk_trion_pll_ops` / `clk_trion_fixed_pll_ops` | 4 / 4 | overlay（CAF 框架前移） |

→ 四个 B1 目标驱动都真实编入内核，而不是"只有开关打开"。

## 3. 顺带发现（尚未修复，记录在案）

1. **`CONFIG_QCOM_CLK_RPMH` 没能生效**：ACK 5.10 有该符号（`drivers/clk/qcom/clk-rpmh.c`），但它 `depends on QCOM_RPMH`，
   而 `gki_defconfig` 里 `QCOM_RPMH` 未开，因此 `config/bringup-cepheus.config` 里写的 `=y` 被 merge_config 丢弃，
   `kernel.config` 中**没有** `CONFIG_QCOM_CLK_RPMH`。DT 里 `qcom,sm8150-rpmh-clk` 节点要靠它。
   → 修法：fragment 里同时写 `CONFIG_QCOM_RPMH=y`。留给 B2/B3 批次验证（不影响 B1a/B1 验收条款）。
2. **DT 时钟 ID 与驱动编号空间的对应关系尚未实证**：DTS 引用 CAF 命名空间的 `qcom,*cc-sm8150-cepheus.h`，
   而 gcc/gpucc/videocc 用 ACK 驱动（ACK 自己的编号）。B1 只验证"编进内核"，**没有验证运行时时钟 ID 对齐**。
   已实测 `dispcc` 的 `-cepheus` 头与 CAF 原生头 63 项完全一致；gcc/gpucc/videocc 三者的差异留给真机验证阶段暴露。

## 4. 判定

- **B1a 达成**：CAF clk 框架扩展（`vdd-level.h`、`clk-alpha-pll.[ch]` 等 17 文件，D015 第一批）已导入并登记，构建 `error:` = 0。
- **B1 达成**：`camcc/dispcc/npucc/scc-sm8150` 四个驱动同时满足"构建成功 / 配置 =y / 符号存在"三条。
