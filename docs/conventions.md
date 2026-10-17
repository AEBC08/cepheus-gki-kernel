# 代码与提交规范（执行细则）

> 决策依据见 `memory/decisions/D005-repo-and-conventions.md`。本文件只写"怎么做"，是提交前的检查清单。

## 1. 提交前检查清单

一个提交合入前必须全部满足：

- [ ] 只做一件事（驱动变更 / DTS 变更 / 配置变更不混在同一次提交）
- [ ] 可以单独 `git revert` 而不牵动其它改动
- [ ] `scripts/checkpatch.pl --strict <patch>` 无 error；warning 要么修，要么在提交信息里解释
- [ ] 至少能编过（`Image.gz` + `dtbs` 成功）
- [ ] 提交信息包含：动机、实现选择、验证方式、`Signed-off-by`
- [ ] 移植类提交标注来源（`UPSTREAM:` / `BACKPORT:` / `FROMGIT:` / `CHERRY-PICK`）与原 commit/仓库/分支/原作者

## 2. 提交信息模板

新建 `~/.gitmessage-cepheus`（或在工作树 `git config commit.template` 指向它）：

```
<subsystem>: <祈使式摘要，<=72 字符>

问题现象 / 根因 / 为什么必须改。

关键实现选择，以及为什么不用更显而易见的替代方案。

验证：
- <实机/编译/日志证据>

Signed-off-by: Name <email>
```

常用 `subsystem` 前缀：`arm64: dts:`、`arm64: configs:`、`clk: qcom:`、`interconnect: qcom:`、`techpack: display:`、`techpack: camera:`、`techpack: audio:`、`drm/msm:`、`kgsl:`、`soc: qcom:`、`usb: dwc3:`、`ufs: qcom:`、`input: fts_521:`。

## 3. 常用命令

```bash
# 生成补丁并检查风格
git format-patch -1 --stdout > /tmp/p.patch
scripts/checkpatch.pl --strict --no-signoff /tmp/p.patch

# 一次提交只含指定路径（避免误带无关改动）
git add -- arch/arm64/boot/dts/xiaomi/cepheus/
git commit -s

# 打发布 tag（仅限已实机验证的 commit）
git tag -a cepheus-5.10-20261017 -m "cepheus GKI 5.10 bringup: <要点>"
```

## 4. 移植类提交的来源标注写法

```
arm64: dts: import cepheus panel EA8076 dt nodes

CHERRY-PICK from 5.4 前移树：qaz6750/android_kernel_xiaomi_sm8150
branch android-5.4.y, commit <sha> ("<原摘要>"), author <原作者>.

为适配 5.10 binding 做了以下修改：
- <改动 1 及原因>
- <改动 2 及原因>

验证：dtb 编译通过；实机面板点亮。

Signed-off-by: ...
```

## 5. 禁止事项

- 禁止整树 merge 4.14 社区树（会引入不可追溯改动）。
- 禁止提交"编不过"的中间态到 `cepheus-5.10`。
- 禁止对已发布 tag 或 `cepheus-5.10` 做 force-push。
- 禁止把编译产物（`out/`、`*.ko`、`Image*`、`*.dtb`、`*.dtbo`）提交进任何仓库。
- 禁止用"格式化/重排"类改动污染移植 diff。

## 6. 文档规范（本控制仓库）

- 一文件一主题；决策进 `memory/decisions/`，调研数据进 `memory/findings/`。
- 结论必须区分"已验证"与"判断（未验证）"。
- 禁止整段粘贴命令原始输出；摘要 + 关键证据即可。
- 修改既有决策时不改写历史，另起新编号。
