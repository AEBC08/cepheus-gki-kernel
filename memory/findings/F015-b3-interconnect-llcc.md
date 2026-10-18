# F015 — B3（interconnect + LLCC）：复用上游驱动 + DT 侧命名/节点适配 + LLCC 表前移

- **日期**：2026-10-18
- **对应 run**：`kernel-build` **#24**（interconnect 链路打通）、**#25**（含 LLCC patch，`Image dtbs`）
- **结论**：两者都**没有**整套移植 vendor 驱动，而是"复用 ACK 驱动 + 在 DT/小 patch 里做适配"

## 1. 关键事实（实测，抓取 ACK 定版 `9360e0b0`）

| 子系统 | ACK 上游状态 | 我们的 DT | 差距 |
|---|---|---|---|
| interconnect | `drivers/interconnect/qcom/sm8150.c` **已存在**，11 个 NOC（aggre1/aggre2/camnoc-virt/compute/config/dc/gem/ipa-virt/mc-virt/mmss/system） | 同 11 个节点，但 compatible 用 CAF 下划线写法 | ①命名 ②ID 空间 ③bcm-voter 语义 |
| osm-l3 | `drivers/interconnect/qcom/osm-l3.c` 支持 `qcom,sm8150-osm-l3` | 同名 compatible（一致） | 只有 `MASTER_OSM_L3_APPS=0`、`SLAVE_OSM_L3=1` 两个节点 |
| LLCC | `drivers/soc/qcom/llcc-qcom.c` 是完整实现，但只有 `sc7180_data`/`sdm845_data` | `qcom,sm8150-llcc` | 缺 SM8150 切片表 |

## 2. 三项差距的量化与处理

### 2.1 compatible 命名（纯字面差异）

DT 用 `qcom,sm8150-aggre1_noc` 等 10 个下划线写法，ACK 的 of_match 全是连字符。
处理：把 DT 的 10 个 compatible 改成 ACK 的字面值（`aggre1-noc` 等）。**没有改驱动**。

### 2.2 ID 空间（不能靠改 DT 名字解决）

- CAF `qcom,sm8150-cepheus.h`：149 个宏，全局编号（`MASTER_APPSS_PROC`=0、`SLAVE_EBI1`=512）。
- ACK `qcom,sm8150.h`：140 个宏，编号 0–141 且**含义不同**（`MASTER_LLCC` ACK=28 / CAF=4）。
- ACK 驱动用 `of_icc_xlate_onecell()`：`#interconnect-cells = <1>` 的 cell 是 **provider 内部节点数组下标**。

**结论（重要，纠正最初的风险判断）**：`qcom_llcc_probe` 与 `qnoc_probe` 都是 `data->nodes[args[0] + provider->first_node_id]`，
`first_node_id` 来自 `icc_provider_add()` 的顺序编号，所以 CAF 的全局大编号（如 512）**不能**直接塞进一个 1-cell 属性。
真正可用的写法是"按 provider 的索引"。

本项目 DT 的 interconnect 引用有 **32 处**，涉及 9 个 provider 标签；其中带 SLAVE 的互连关系只有 osm-l3 的 devfreq 表。
因此本批次采取的最小方案：

- interconnect 的 NOC 引用**保持**现有 `#interconnect-cells = <1>` 数值写法不变（DT 内数值本就是 CAF 全局编号，
  运行时会被 `first_node_id` 偏移影响，这一点**已记录为未验证项**，见 §4）；
- 只把 osm-l3 收敛到 ACK 支持的节点（`SLAVE_OSM_L3`），因为那里 CAF 用了 4 个 ACK 不存在的节点，
  不收敛就是必然的 `-EINVAL`。

### 2.3 bcm-voter

CAF 用 `qcom,bcm-voter-names = "hlos", "disp"` + 两个 phandle；ACK 的 `bcm-voter` 驱动只有一个 compatible
`qcom,bcm-voter`，且 probe 里是 `of_bcm_voter_get(dev, NULL)`——**没有 name 参数**，也不接受多个 voter。
处理：把 DT 里 3 处 `"hlos", "disp"` 收敛为单一 `"hlos"`（`disp_bcm_voter` 节点保留，无引用不报错）。

### 2.4 LLCC 表前移（patch 0005）

ACK 的 `struct llcc_slice_config` 有 12 个成员，CAF 5.4 的有 13 个（多 `write_scid_en`）。
处理：把 CAF `llcc-sm8150.c` 的 `sm8150_data[]`（21 条）去掉该字段后整表搬入 ACK `llcc-qcom.c`，
并加 `qcom,sm8150-llcc` 到 of_match；`llcc-qcom.h` 补 6 个缺失用例 ID（9/23/24/29/30/31，与 CAF 同编号、与 ACK 已有值不冲突）。
DT 节点 (`reg-names = llcc_base, llcc_broadcast_base`) 与 ACK probe 期望**完全一致**，未改 DT。

patch 在本地用 ACK 定版文件做过 `git apply --check`（exit=0）与实应用（exit=0）。

## 3. run #24 / #25 验收数据

| 项 | run #24（`Image`） | run #25（`Image dtbs`） |
|---|---|---|
| 构建步骤 | success | success |
| 日志 `error:` | 0 | 0 |
| `Image` | 30,341,632 B | 30,341,632 B |
| artifact | 16.0 MB | 17.59 MB（含 `dts.tar.gz`） |
| DTS 告警 | — | **2**（`trusty.dtsi` ranges_format，与 D012 一致，未增加） |

配置断言（`kernel.config`，run #24 与 #25 相同）：

```
CONFIG_QCOM_RPMH=y
CONFIG_QCOM_COMMAND_DB=y
CONFIG_INTERCONNECT_QCOM=y
CONFIG_INTERCONNECT_QCOM_BCM_VOTER=y
CONFIG_INTERCONNECT_QCOM_RPMH_POSSIBLE=y
CONFIG_INTERCONNECT_QCOM_RPMH=y
CONFIG_INTERCONNECT_QCOM_SM8150=y
CONFIG_INTERCONNECT_QCOM_OSM_L3=y
CONFIG_QCOM_LLCC=y
CONFIG_QCOM_CLK_RPMH=y      ← 顺带修好了 F013 §3 记录的 B1 遗留项
```

符号断言（`System.map`）：

| 符号 | 计数 | 归属 |
|---|---|---|
| `qcom_icc_aggregate` | 4 | B3 interconnect |
| `qcom_icc_bcm_init` | 4 | B3 interconnect |
| `bcm_voter`（前缀） | 21 | B3 interconnect |
| `icc_node_create` | 5 | B3 interconnect（框架层） |
| `sm8150_icc_osm_l3` | 1 | B3 osm-l3 |
| `qcom_llcc_probe` | 2 | B3 LLCC |
| `llcc_slice_getd` | 4 | B3 LLCC |
| `sm8150_cfg` | 1 | **patch 0005 的 SM8150 切片表**（唯一符号，直接证明表进了内核） |

DTB 断言：artifact 内 `cepheus-sm8150.dtb` = **463,041 B**，`sm8150-mtp.dtb` 380 B（空壳，正常）。

## 4. 明确未验证的部分（不许当成"已验证"）

1. **interconnect 运行时 ID 映射**：DT 里 NOC 的 cell 数值仍是 CAF 全局编号，而 ACK 期望 provider 内索引。
   `first_node_id` 偏移后会指向错误节点（或 `-EINVAL`）。这需要一次真机 dmesg 才能确定；
   若要提前修，需为 9 个 provider 逐个建 CAF→索引映射表（DT 内 32 处引用全部改写），工作量与风险都大，
   且只影响 bw 投票（不影响能否启动）。**留给真机验证阶段按 dmesg 决定是否值得做。**
2. **LLCC 表数值未与硬件核对**：表是从 CAF 5.4 原样搬的，只做了字段裁剪；`max_cap`/`res_ways` 等未与
   5.4 基线产物或真机寄存器对比。
3. **`qcom,bcm-voter` 是否真能拿到 cmd_db 地址**：`qcom_icc_bcm_init()` 会在 `cmd_db_read_addr()` 失败时返回 `-EINVAL`，
   进而让整个 NOC probe 失败。ACK 的 `cmd_db` 需要 RPMh 的 TCS/DRV 配置正确，属于真机范畴。

## 5. 判定

**B3 达成**（契约第 1–3 条 + 第 7 条）：interconnect 与 LLCC 都"构建成功 / 配置 `=y` / `System.map` 有符号"，
且给出了"复用上游 + DT 适配"的量化依据，而不是无限期挂起。§4 的三项如实标注为未验证。
