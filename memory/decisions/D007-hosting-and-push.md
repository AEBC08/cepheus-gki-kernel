# D007 — 代码托管：公开 GitHub 仓库与推送方式

- **状态**：已定并已执行（公开仓库已创建、代码已推送；凭据问题已解决）
- **日期**：2026-10-17
- **决策者**：用户（"推送到我个人仓库就行了，公开仓库"）+ PI-Desktop 执行

## 背景

用户要求把本控制仓库推送到其个人 GitHub 仓库并设为**公开**。Bootstrap 与构建 workflow 依赖 GitHub Actions，公开仓库可免费使用。

## 决策

1. **托管位置**：GitHub 个人账号，**公开**仓库。
   - 账号：`AEBC08`（与提交身份一致，**受网络影响未能通过 API 复核，待用户确认**）
   - 仓库名：`cepheus-gki-kernel`（待确认）
   - 默认分支：`main`
2. **提交身份（仓库级，非全局）**：`AEBC08 <743727279@qq.com>`
   —— 仅写入本仓库 `.git/config`，不修改用户全局 git 配置。
3. **仓库内容边界**：本仓库只放决策、文档、脚本与 CI；内核源码树在 `src/`（已被 `.gitignore` 排除），内核仓库将来单独建立（D005）。

## 已执行（已验证）

| 项 | 结果 |
|---|---|
| `git init -b main` | 完成 |
| 仓库级提交身份 | `AEBC08 <743727279@qq.com>` |
| 初始提交 | `c163fde`，22 个文件，1534 行新增 |
| 提交信息 | 遵循 D005：`project: …` + 动机 + 验证 + `Signed-off-by` |

## 实测约束（已验证，决定了推送必须由用户授权）

| 项 | 状态 |
|---|---|
| `gh` CLI | **未安装** |
| `GH_TOKEN` / `GITHUB_TOKEN` 环境变量 | **未设置** |
| `credential.helper` | **未配置** |
| `~/.git-credentials` | **不存在** |
| `~/.ssh` | **不存在（无任何 SSH key）** |
| `git@github.com:22` | **连接被拒**（本网络封锁或不可达） |
| `api.github.com` | 时通时超时（多次 15–25 s 超时）；`raw.githubusercontent.com` 与 `github.com` HTTPS 可用 |

→ 结论：**无法由本机代用户创建仓库或推送**；不做任何凭据的猜测或伪造。

## 待用户选择的认证方式（Q010）

- **A（推荐）**：用户在网页创建空公开仓库，并提供 fine-grained PAT（权限仅需该仓库的 `Contents: Read and write`）。PI-Desktop 负责 `git push`，**不留存 token**：仅在单次命令中通过临时 `credential` 注入，推送后立即清除 remote 中的凭据痕迹。
- **B**：用户在本机安装 GitHub CLI 并执行 `gh auth login`（交互式，仅用户可完成），之后由 PI-Desktop 执行 `gh repo create --public --source . --push`。
- **C**：用户自行在网页创建空仓库并自行 `git push`（PI-Desktop 给出完整命令），后续 CI 仍可正常工作。

## 影响与后续

- 无论哪种方式，推送后需确认：Actions 已启用（公开仓库默认启用）、`bootstrap-sources` 可手动触发。
- **安全要求**：token 绝不写入文件、不写入 remote URL 的持久配置、不进入提交信息；如用户粘贴 token 到对话中，建议推送完成后立即在 GitHub 上吊销并重新生成。
- 复核触发：若 HTTPS 推送因本机网络中断失败，改用 `git push` 分段重试；仍失败则请用户从自己网络推送。
