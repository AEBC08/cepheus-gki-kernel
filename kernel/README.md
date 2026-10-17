# kernel/ — 我们自己的内核改动

内核树（ACK `android12-5.10`，约 1.2 GB）**不入 git**，见 `memory/decisions/D008`、`D010`。
本目录承载我们自己的改动，由 `scripts/prepare-kernel.sh` 在构建前应用到拉取下来的树上。

| 目录 | 用途 | 复制方式 |
|---|---|---|
| `overlay/` | **新增**文件，目录结构 = 内核树相对路径 | `rsync -a kernel/overlay/ src/kernel/` |
| `patches/` | **修改** ACK 既有文件的补丁（`*.patch`，按文件名排序） | 依次 `git apply` |

## 重要约束

1. `overlay/` 里**只能放内核树里的真实文件**。任何说明文档、临时文件都会被原样复制进内核树
   （曾经把 `overlay/README.md` 复制成内核根目录的 `README.md`，见 F008）。
   文档请写在本目录（上层），不要放进 `overlay/`。
2. 修改既有文件必须走 `patches/`，不要用 overlay 覆盖整文件。
3. `prepare-kernel.sh` 每次都会先 `git reset --hard` + `git clean -fdx`，overlay 内容是构建的唯一来源。

## 本地自检

```bash
bash scripts/prepare-kernel.sh --check   # 只做 git apply --check
bash scripts/prepare-kernel.sh           # 真正落盘（幂等）
```
