# F009 — CAF techpack 来源调查（R10 的结论）

- **日期**：2026-10-18
- **方法**：`git.codelinaro.org` GitLab API（`/repository/branches?search=` 与 `/repository/tags`）。以下均为**已验证事实**。

## 1. 结论先行

| techpack | 有 5.10 分支吗 | 实际发布方式 |
|---|---|---|
| `display-drivers` | **有** | 分支 `display-kernel.lnx.5.10.{r2,r3,r8,r10,r11}-rel`、`display-kernel.lnx.5.10.2.r1-rel` |
| `audio-kernel` | **没有** | 只有 release **tag**（如 `LA.UM.9.12.c25-06000-SMxx50.QSSI13c28.0`、`LA.UM.9.14.1.c26-03300-QCM6490.QSSI13c29.0`） |
| `camera-kernel` | **没有** | 只有 tag（如 `LA.VENDOR.16.2.13.r1-04200-DIVAR.QISI17.0`、`CAMERA.LA.5.0.r3-01300-pakala.0`） |
| `video-driver` | **没有** | 只有 tag + 少量 `video-kernel-waipio.lnx.1.0.r*-rel`、`caf_migration/video-kernel.lahaina.*` 分支 |

检索词 `lnx.5.10` / `msm-5.10` / `lahaina` / `bengal` / `waipio` 对 audio/camera 均 **0 命中分支**；
video-driver 仅命中 `lahaina`/`waipio` 的旧式分支名。

## 2. 为什么 5.4 前移树能合并 audio-kernel

该树的一次提交是：

```
Merge tag 'LA.UM.9.14.r1-26700-LAHAINA.QSSI16.0' of .../audio-kernel
```

→ 说明**前人的做法也是按 tag 取**，而不是按分支。这与我们观察到的"audio/camera 没有 5.10 分支"一致。

## 3. 对 5.10 的选型含义

- **display** 直接用分支（已确认、已 pin：`display-kernel.lnx.5.10.r8-rel` = `ecf501e1…`）。
- **audio / camera / video** 必须按 **CAF release tag** 取。tag 名里带平台与 Android 版本标记
  （`WAIPIO` / `QSSI16.0` / `QISI17.0` 等），需要一条**映射规则**，而不能只看版本号。

### 建议的映射规则（待验证，不写死）

1. 以 **display 的 5.10 分支**为准绳，找出与其同一代（同 `lnx.5.10` 系列、相近提交日期）的 tag；
2. 优先选 **`*QSSI*` / `*QISI*` 且平台标记为 waipio 一代（5.10 对应 SM8450/waipio）** 的 tag；
3. 同一 tag 在三仓库中若缺失，退而取"时间上最近的同系列"。

## 4. 仍未解决

- 三仓库 tag → 平台/内核版本 的**官方映射表并不公开**，需要逐仓库比对 tag 内 `Makefile`/`Kbuild`
  里的内核版本假设（可作为下一步的自动校验手段：取 tag 后检查其源码是否引用 5.10 才有的 API）。
- 因此 R10 **不关闭**，但已从"不知道存在什么"变为"知道必须走 tag + 有判定流程"。
- 对 S2 的影响：display 可以先接入；audio/camera/video 的接入排在 tag 选型之后。

## 5. 顺带确认

- `display-drivers` 的 5.10 分支共 17 个（含 `.5.10.2` 与 `.5.15.10` 系列），最新提交 2026-08-27。
- `camera-kernel` / `audio-kernel` 的 tag 列表按提交时间倒序，最新 tag 已到 `QISI17.0` / `QISI17.0` 一代。
