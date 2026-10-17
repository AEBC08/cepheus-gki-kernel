#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# build-kernel.sh — 构建 cepheus GKI(5.10) 内核。
#
# 设计目标：
#   1. 同一份脚本在 CI（GitHub Actions）与 WSL2 中行为一致；
#   2. 产物自带元数据（build-info.txt），可回溯到"源码 commit + 工具链 + 配置"；
#   3. 配置一律通过 merge_config.sh 生成，禁止手改 out/.config。
#
# 用法：
#   scripts/build-kernel.sh [--check]
#     --check   只校验参数、内核树与工具链，不做编译（可在无编译环境的机器上跑）
#
# 环境变量（括号内为默认值）：
#   KERNEL_DIR     (src/kernel)                       内核树根目录
#   OUT_DIR        (out)                              构建输出目录
#   ARTIFACT_DIR   (out/artifacts)                    产物收集目录
#   ARCH           (arm64)
#   JOBS           (nproc)                            并行度
#   DEFCONFIG      (gki_defconfig)                    相对 arch/$ARCH/configs/
#   DEVICE_CONFIGS ()                                 逗号分隔的 config 片段（相对上述目录或绝对路径）
#   TARGETS        (Image)                            空格分隔的 make 目标，如 "Image dtbs"
#   USE_LLVM       (1)                                1=LLVM=1 LLVM_IAS=1；0=用 CROSS_COMPILE
#   CROSS_COMPILE  (aarch64-linux-gnu-)               USE_LLVM=1 时用于推导 clang --target；=0 时作为实际交叉前缀
#   CCACHE         (0)                                1=用 ccache 包装 clang（CI 增量构建）
#   ALLOW_MISMATCH (0)                                1=允许内核主/次版本不是 5.10（不推荐）
#
# 退出码：0 成功；非 0 失败（stderr 给出原因）

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

KERNEL_DIR=${KERNEL_DIR:-${REPO_ROOT}/src/kernel}
OUT_DIR=${OUT_DIR:-${REPO_ROOT}/out}
ARTIFACT_DIR=${ARTIFACT_DIR:-${OUT_DIR}/artifacts}
ARCH=${ARCH:-arm64}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}
DEFCONFIG=${DEFCONFIG:-gki_defconfig}
DEVICE_CONFIGS=${DEVICE_CONFIGS:-}
TARGETS=${TARGETS:-Image}
USE_LLVM=${USE_LLVM:-1}
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
CCACHE=${CCACHE:-0}
ALLOW_MISMATCH=${ALLOW_MISMATCH:-0}

CHECK_ONLY=0

log()  { printf '[build] %s\n' "$*"; }
warn() { printf '[build] WARN: %s\n' "$*" >&2; }
die()  { printf '[build] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '3,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

main() {
  case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) die "未知参数：$1（可用：--check, --help）" ;;
  esac

  log "KERNEL_DIR   = ${KERNEL_DIR}"
  log "OUT_DIR      = ${OUT_DIR}"
  log "DEFCONFIG    = ${DEFCONFIG}"
  log "DEVICE_CONFIGS = ${DEVICE_CONFIGS:-<无>}"
  log "TARGETS      = ${TARGETS}"
  log "JOBS         = ${JOBS}"

  check_kernel_tree
  check_toolchain
  check_fragments

  if [ "${CHECK_ONLY}" -eq 1 ]; then
    log "--check 通过（未执行编译）"
    return 0
  fi

  local -a make_args=("ARCH=${ARCH}" "O=${OUT_DIR}")
  if [ "${USE_LLVM}" -eq 1 ]; then
    # Linux 5.10 从 CROSS_COMPILE 推导 clang 的 --target 三元组；只给 LLVM=1 会让
    # clang 退回宿主机(x86_64)目标，编 arm64 内联汇编时报 unknown register name 'x0'。
    make_args+=("LLVM=1" "LLVM_IAS=1" "CROSS_COMPILE=${CROSS_COMPILE}")
    if [ "${CCACHE}" -eq 1 ]; then
      command -v ccache >/dev/null 2>&1 || die "CCACHE=1 但未找到 ccache"
      make_args+=("CC=ccache clang")
    fi
  else
    make_args+=("CROSS_COMPILE=${CROSS_COMPILE}")
  fi

  # shellcheck disable=SC2206  # TARGETS 有意按空格拆分
  local -a targets=(${TARGETS})

  mkdir -p -- "${OUT_DIR}" "${ARTIFACT_DIR}"

  configure "${make_args[@]}"

  local make_cmd=(make -C "${KERNEL_DIR}" -j"${JOBS}" "${make_args[@]}" "${targets[@]}")
  log "开始编译：${make_cmd[*]}"
  "${make_cmd[@]}"

  write_build_info "${make_cmd[*]}"
  collect_artifacts
  log "构建完成，产物在 ${ARTIFACT_DIR}"
}

check_kernel_tree() {
  [ -f "${KERNEL_DIR}/Makefile" ] || die "未找到 ${KERNEL_DIR}/Makefile（先运行 scripts/fetch-sources.sh）"
  [ -x "${KERNEL_DIR}/scripts/kconfig/merge_config.sh" ] || [ -f "${KERNEL_DIR}/scripts/kconfig/merge_config.sh" ] \
    || die "未找到 ${KERNEL_DIR}/scripts/kconfig/merge_config.sh，内核树不完整"

  local version patchlevel
  version=$(awk -F' = ' '/^VERSION =/{print $2}' "${KERNEL_DIR}/Makefile")
  patchlevel=$(awk -F' = ' '/^PATCHLEVEL =/{print $2}' "${KERNEL_DIR}/Makefile")
  if [ "${version}" != "5" ] || [ "${patchlevel}" != "10" ]; then
    if [ "${ALLOW_MISMATCH}" -eq 1 ]; then
      warn "内核版本为 ${version}.${patchlevel}，非预期 5.10（ALLOW_MISMATCH=1，继续）"
    else
      die "内核版本为 ${version}.${patchlevel}，期望 5.10（确需构建请设 ALLOW_MISMATCH=1）"
    fi
  else
    log "内核版本：5.${patchlevel}"
  fi
}

check_toolchain() {
  if [ "${USE_LLVM}" -eq 1 ]; then
    command -v clang >/dev/null 2>&1 || die "未找到 clang（Ubuntu: apt-get install clang lld llvm）"
    command -v ld.lld >/dev/null 2>&1 || die "未找到 ld.lld（Ubuntu: apt-get install lld）"
    log "clang: $(clang --version | head -n1)"
  else
    command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1 \
      || die "未找到 ${CROSS_COMPILE}gcc（USE_LLVM=0 需要交叉 gcc）"
    log "cross gcc: $(${CROSS_COMPILE}gcc --version | head -n1)"
  fi

  local tool
  for tool in bc flex bison cpio; do
    command -v "${tool}" >/dev/null 2>&1 || warn "未找到 ${tool}，配置/编译阶段可能失败"
  done
}

# 校验 config 片段存在；返回解析后的绝对路径数组（通过全局 FRAGMENTS）
FRAGMENTS=()
check_fragments() {
  FRAGMENTS=()
  [ -n "${DEVICE_CONFIGS}" ] || return 0

  local cfg_dir="${KERNEL_DIR}/arch/${ARCH}/configs"
  local item path
  local -a items
  IFS=',' read -r -a items <<< "${DEVICE_CONFIGS}"
  for item in "${items[@]}"; do
    [ -n "${item}" ] || continue
    if [ -f "${item}" ]; then
      path=${item}
    elif [ -f "${cfg_dir}/${item}" ]; then
      path=${cfg_dir}/${item}
    else
      die "config 片段不存在：${item}（相对 ${cfg_dir} 或绝对路径）"
    fi
    FRAGMENTS+=("${path}")
  done
  [ -f "${cfg_dir}/${DEFCONFIG}" ] || die "defconfig 不存在：${cfg_dir}/${DEFCONFIG}"
  log "config 片段：${FRAGMENTS[*]}"
}

configure() {
  local -a make_args=("$@")

  if [ "${#FRAGMENTS[@]}" -eq 0 ]; then
    log "配置：make ${DEFCONFIG}（无机型片段）"
    make -C "${KERNEL_DIR}" "${make_args[@]}" "${DEFCONFIG}"
    return 0
  fi

  [ -f "${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}" ] \
    || die "defconfig 不存在：arch/${ARCH}/configs/${DEFCONFIG}"

  log "配置：merge_config.sh ${DEFCONFIG} + ${#FRAGMENTS[@]} 个片段"
  KCONFIG_CONFIG="${OUT_DIR}/.config" \
    "${KERNEL_DIR}/scripts/kconfig/merge_config.sh" -m -O "${OUT_DIR}" \
    "${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}" "${FRAGMENTS[@]}"
  make -C "${KERNEL_DIR}" "${make_args[@]}" olddefconfig
}

write_build_info() {
  local make_cmd=$1
  local info="${ARTIFACT_DIR}/build-info.txt"
  local head branch dirty clang_ver cfg_sha
  head=$(git -C "${KERNEL_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")
  branch=$(git -C "${KERNEL_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  dirty=$(git -C "${KERNEL_DIR}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  clang_ver=$(clang --version 2>/dev/null | head -n1 || echo "n/a")
  cfg_sha=$(sha256sum "${OUT_DIR}/.config" 2>/dev/null | awk '{print $1}' || echo "n/a")

  {
    printf 'project      = cepheus GKI 5.10\n'
    printf 'built_at     = %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'kernel_head  = %s\n' "${head}"
    printf 'kernel_branch= %s\n' "${branch}"
    printf 'dirty_files  = %s\n' "${dirty}"
    printf 'defconfig    = %s\n' "${DEFCONFIG}"
    printf 'fragments    = %s\n' "${DEVICE_CONFIGS:-<无>}"
    printf 'config_sha256= %s\n' "${cfg_sha}"
    printf 'toolchain    = %s\n' "${clang_ver}"
    printf 'make_command = %s\n' "${make_cmd}"
    printf 'pins         = %s\n' "$( [ -f "${REPO_ROOT}/src/techpack/PINS.txt" ] && echo "见 src/techpack/PINS.txt" || echo "无（未拉取 techpack）")"
  } > "${info}"

  log "元数据写入 ${info}"
  [ "${dirty}" = "0" ] || warn "内核树存在 ${dirty} 个未提交改动，产物不可复现到某个 commit"
}

collect_artifacts() {
  local boot_dir="${OUT_DIR}/arch/${ARCH}/boot"
  local copied=0

  local -a candidates=(
    "${boot_dir}/Image"
    "${boot_dir}/Image.gz"
    "${boot_dir}/Image.lz4"
    "${boot_dir}/dts"
    "${boot_dir}/dtb.img"
    "${boot_dir}/dtbo.img"
    "${OUT_DIR}/System.map"
    "${OUT_DIR}/Module.symvers"
    "${OUT_DIR}/.config"
  )

  local item
  for item in "${candidates[@]}"; do
    if [ -f "${item}" ]; then
      cp -f -- "${item}" "${ARTIFACT_DIR}/"
      copied=$((copied + 1))
    fi
  done

  # dtb 目录整体打包，便于核对设备树是否生成
  if [ -d "${boot_dir}/dts" ]; then
    ( cd "${boot_dir}" && tar -czf "${ARTIFACT_DIR}/dts.tar.gz" dts )
    copied=$((copied + 1))
  fi

  if [ "${copied}" -eq 0 ]; then
    die "未收集到任何产物，检查 TARGETS='${TARGETS}' 与 ${boot_dir}"
  fi

  log "已收集 ${copied} 项产物："
  ls -la -- "${ARTIFACT_DIR}"
}

main "$@"
