# src/ — 源码工作区（内容不入 git）

本目录**在仓库里是空的**，这是设计结果，不是遗漏。原因有两个，都是硬事实：

1. `.gitignore` 排除了 `/src/kernel/` 与 `/src/techpack/`（内核树约 1.2 GB，见 D008 的取舍说明）。
2. **git 本身不跟踪空目录**——即使没有 ignore 规则，一个只有子目录没有文件的目录也不会出现在提交里。

## 源码从哪来

| 场景 | 方式 |
|---|---|
| CI（GitHub Actions） | `scripts/fetch-sources.sh` 自动拉取，并缓存（键 `src-ack-<pin>-v1`）。首次约 2–4 分钟，之后走缓存约 1–2 分钟。 |
| 本地 Linux / WSL2 | 运行 `bash scripts/fetch-sources.sh` 填充本目录 |
| 想要一份可下载的快照 | 触发 `bootstrap-sources` 工作流，勾选 `publish_snapshot` → 源码以 **Release 资源**（`ack-5.10-<sha>.tar.zst`）发布，可长期下载，但不进 git 历史 |

## 内容说明

- `src/kernel/` — ACK 底板（`android12-5.10`），由 `scripts/fetch-sources.sh` 检出
- `src/techpack/` — CAF vendor 驱动 staging（display/audio/camera/video），附 `PINS.txt` 记录各仓库 HEAD SHA

## 为什么不把源码提交进仓库

- ACK 树约 1.2 GB，一旦进入 git 历史就**永久**留在每个克隆里；GitHub 对 >1 GB 仓库会给出警告。
- 本项目所在网络实测**连 200 MB 级 pack 都推不上去**（连续两次 `curl 18 transfer closed`），1.2 GB 的仓库从本机基本无法维护。
- 缓存键修正（D008）已把"每轮重新下载"的浪费消除，等价达成"不用每次拉取"的目标。

详见 `memory/decisions/D008-bringup-lto-and-cache.md`。
