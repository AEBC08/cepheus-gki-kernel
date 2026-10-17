# kernel/overlay/ — 新增文件（原样复制进内核树）

本目录的**目录结构必须与内核树一致**，例如：

```
kernel/overlay/arch/arm64/boot/dts/xiaomi/cepheus/cepheus-sm8150.dtsi
        ↓ 复制到
src/kernel/arch/arm64/boot/dts/xiaomi/cepheus/cepheus-sm8150.dtsi
```

## 规则（决策见 `memory/decisions/D010-kernel-change-carrying.md`）

1. **只放新增文件**。修改 ACK 既有文件（如 dts 的 `Makefile`）请走 `kernel/patches/`，
   否则整文件覆盖会在上游更新时静默丢失改动。
2. 目录结构即内核树相对路径，不接受"_源_/目标_"之类的映射。
3. `scripts/prepare-kernel.sh` 每次执行前会把内核树 `git reset --hard` + `git clean -fdx`，
   所以这里的内容是**每次构建的真实来源**，不要依赖任何未提交的本地修改。
