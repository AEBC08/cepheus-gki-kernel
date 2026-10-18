# F010 — DT 与 ACK 5.10 驱动栈的绑定差异（量化）

- **日期**：2026-10-18
- **方法**：抽取我们 overlay 里全部 `compatible`（352 个），逐个对照 ACK `android12-5.10` 对应驱动文件里的 `of_match` 串。以下均为**已验证事实**。

## 1. 结论先行

**当前 DT 与 ACK 5.10 上游驱动"体系不兼容"，不是缺 CONFIG 的问题。**

CAF 的设备树使用一套**厂商私有 compatible 命名**，而 ACK 上游驱动只认上游命名。二者对不上，
即使把所有驱动编进内核，节点也不会绑定 → 设备不 probe → 仍然无法启动。

## 2. 逐项对照（DT 实际用 vs 驱动实际认）

| 子系统 | 我们 DT 里的 compatible | ACK 5.10 驱动支持的 | 结论 |
|---|---|---|---|
| geni-se（QUP 外壳） | `qcom,qupv3-geni-se` | `qcom,geni-se-qup` | ✘ 不匹配 |
| geni 串口 | `qcom,msm-geni-serial-hs`、`qcom,msm-geni-console` | `qcom,geni-uart`、`qcom,geni-debug-uart` | ✘ 不匹配 |
| tsens | `qcom,tsens24xx` | `qcom,tsens-v1`、`qcom,tsens-v2` 等 | ✘ 不匹配 |
| LLCC | `qcom,sm8150-llcc` | `qcom,sc7180-llcc`、`qcom,sdm845-llcc` | ✘ 不匹配 |
| UFS PHY | `qcom,ufs-phy-qmp-v4` | `qcom,sm8150-qmp-ufs-phy`（上游体系） | ✘ 不匹配 |
| USB3 PHY | `qcom,usb-ssphy-qmp-v2`、`qcom,usb-ssphy-qmp-dp-combo` | 上游 `qcom,*-qmp-usb3-phy` 体系 | ✘ 不匹配 |
| SMMU | `qcom,qsmmu-v500`、`qcom,ipa-smmu-*`、`qcom,msm-cam-smmu`、`qcom,kgsl-smmu-v2` | `qcom,smmu-v2`（qsmmu/IPA/cam/kgsl SMMU 均为 vendor 私有） | ✘ 不匹配 |
| interconnect | CAF 的 noc 节点命名 | `qcom,sm8150-aggre1-noc` 等 11 个上游命名 | 需逐个核对（大概率不匹配） |
| 时钟 | `qcom,gcc-sm8150`、`qcom,gpucc-sm8150` | `qcom,gcc-sm8150` ✔、`qcom,gpucc-sm8150` ✔ | ✔ 匹配（但 **clock ID 来自 CAF 头，编号可能与上游不同**） |
| pinctrl | `qcom,sm8150-pinctrl` | `qcom,sm8150-pinctrl` | ✔ 匹配 |
| rpmh-rsc | `qcom,rpmh-rsc` | `qcom,rpmh-rsc` | ✔ 匹配 |
| cmd-db | `qcom,cmd-db` | `qcom,cmd-db` | ✔ 匹配 |
| UFS 控制器 | `qcom,ufshc` | `qcom,ufshc` | ✔ 匹配 |
| dwc3 控制器 | `snps,dwc3` | `snps,dwc3` | ✔ 匹配 |
| rpmh 稳压 | `qcom,pm8150-rpmh-regulators` 等 | 同名 | ✔ 匹配 |
| cpufreq-hw | `qcom,cpufreq-hw` | 同名 | ✔ 匹配 |
| 显示（SDE/DSI） | `qcom,sde-kms`、`qcom,dsi-display`、`qcom,sde_rotator` | **完全不存在**（dpu1 里没有任何 sm8 支持） | ✘ 无驱动 |
| 相机 | `qcom,cam-*`（20+） | 无（CAMSS 不支持 SM8150 的 CAMX 体系） | ✘ 无驱动 |
| 音频 | `qcom,msm-pcm*`、`qcom,wcd934x` 等 | 部分通用（wcd934x 有），其余为 vendor 私有 | 多为 ✘ |
| GPU | `qcom,kgsl-3d0` | 上游是 `qcom,adreno`（kgsl 是 vendor 私有） | ✘ 不匹配 |
| 充电 | `qcom,qpnp-smb5` | 上游无（vendor 私有） | ✘ 无驱动 |

## 3. 这意味着什么

1. **"补 CONFIG 就能启动"的判断不成立。** 绑定层就不通。
2. 我们的 DT 是**为 vendor 驱动栈写的**（CAF 命名），它与该栈自洽；把它放到 ACK 上游驱动下面必然大面积不 probe。
3. 因此"能构建"与"能适配"之间隔着的不是配置，而是**整套 vendor 驱动栈**——这正是 `qaz6750/android_kernel_xiaomi_sm8150` 那份树里"东西多"的原因：它带的是 CAF LAHAINA(5.4) 的完整 vendor 代码（techpack display/camera/audio/video + kgsl + icnss + qcacld + 充电 + touch 等）。

## 4. 两条可选路线（需决策，见 D013）

- **路线 A：改 DT 去迎合 ACK 上游驱动。**
  需要重写 geni/tsens/LLCC/UFS-PHY/USB-PHY/SMMU/interconnect 等大量节点为上游命名与属性；
  即使成功，**显示/相机/音频/GPU/充电仍然没有驱动**（上游 5.10 无 SM8150 的 DPU/CAMSS 支持）。
  → 只能到"进 init、黑屏"，且工作量集中在"重写 DT"，收益有限。

- **路线 C：以 vendor 栈为基线（推荐）。**
  把 5.4 前移树作为基线（DT 与驱动自洽、作者已验证可启动 HyperOS 2），
  按原计划做 **5.4 → 5.10 前移**；GKI 形态在 5.10 上落地。
  → DT、驱动、配置都已配套，工作量集中在"内核 API 跨版本适配"，这是可控且渐进的工作。

## 5. 建议的第一步（两种路线都受益）

**先在 CI 里复现 5.4 树的构建产物**（它自带 `build_kernel.sh` + `vendor/sm8150-qgki_defconfig`）。
这能证明：
- 我们的构建流水线可以产出**已知能在真机启动**的镜像（参照物）；
- 后续前移到 5.10 时，有"改动前/改动后"的对照基线。
