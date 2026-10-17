#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# prepare-kernel.sh — 把本项目自己的内核改动应用到拉取下来的内核树上。
#
# 背景见 memory/decisions/D010-kernel-change-carrying.md：
#   内核树不入 git（1.2 GB），我们的改动以「overlay（新文件）+ patches（修改）」承载。
#
# 幂等性：每次先 `git reset --hard` + `git clean -fdx` 把树恢复到 fetch 后的状态，
#         再铺 overlay、打 patch。因此重复执行结果一致。
#
# 用法：
#   scripts/prepare-kernel.sh [--check]
#     --check  只做 git apply --check，不落盘（用于本地/CI 预检补丁能否应用）
#
# 环境变量（括号为默认值）：
#   KERNEL_DIR   (src/kernel)
#   OVERLAY_DIR  (kernel/overlay)
#   PATCH_DIR    (kernel/patches)

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

KERNEL_DIR=${KERNEL_DIR:-${REPO_ROOT}/src/kernel}
OVERLAY_DIR=${OVERLAY_DIR:-${REPO_ROOT}/kernel/overlay}
PATCH_DIR=${PATCH_DIR:-${REPO_ROOT}/kernel/patches}

CHECK_ONLY=0

log()  { printf '[prepare] %s\n' "$*"; }
warn() { printf '[prepare] WARN: %s\n' "$*" >&2; }
die()  { printf '[prepare] ERROR: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

main() {
  case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) die "未知参数：$1（可用：--check, --help）" ;;
  esac

  [ -f "${KERNEL_DIR}/Makefile" ] || die "未找到 ${KERNEL_DIR}/Makefile（先运行 scripts/fetch-sources.sh）"
  [ -d "${KERNEL_DIR}/.git" ]     || die "${KERNEL_DIR} 不是 git 仓库，无法保证幂等与可回退"

  local patches=()
  collect_patches patches

  if [ "${CHECK_ONLY}" -eq 1 ]; then
    check_patches "${patches[@]+"${patches[@]}"}"
    log "--check 通过"
    return 0
  fi

  reset_tree
  apply_overlay
  apply_patches "${patches[@]+"${patches[@]}"}"
  write_prep_info "${#patches[@]}"
  log "完成"
}

# 收集 patch，按文件名排序（约定：文件名前缀 000N- 表示顺序）
collect_patches() {
  local -n out=$1
  out=()
  if [ -d "${PATCH_DIR}" ]; then
    while IFS= read -r p; do
      out+=("${p}")
    done < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | sort)
  fi
  log "patch 数量：${#out[@]}"
}

reset_tree() {
  log "恢复内核树到 fetch 后状态（git reset --hard && clean -fdx）"
  git -C "${KERNEL_DIR}" reset --hard --quiet
  # -x 会删掉未跟踪文件（含上次 overlay 结果），这正是我们要的干净起点
  git -C "${KERNEL_DIR}" clean -fdxq
}

apply_overlay() {
  if [ ! -d "${OVERLAY_DIR}" ]; then
    warn "无 overlay 目录：${OVERLAY_DIR}"
    return 0
  fi

  local count
  count=$(find "${OVERLAY_DIR}" -type f | wc -l | tr -d ' ')
  if [ "${count}" -eq 0 ]; then
    log "overlay 为空，跳过"
    return 0
  fi

  log "铺设 overlay：${count} 个文件"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' "${OVERLAY_DIR}/" "${KERNEL_DIR}/"
  else
    # 无 rsync 时用 tar 管道保持目录结构与权限
    ( cd "${OVERLAY_DIR}" && tar -cf - --exclude='.git' . ) | ( cd "${KERNEL_DIR}" && tar -xf - )
  fi
}

# 只做可行性检查，不落盘
check_patches() {
  local -a patches=("$@")
  local p
  for p in "${patches[@]+"${patches[@]}"}"; do
    log "检查 patch：$(basename -- "${p}")"
    git -C "${KERNEL_DIR}" apply --check --whitespace=nowarn "${p}" \
      || die "patch 无法应用：${p}"
  done
}

apply_patches() {
  local -a patches=("$@")
  local p
  for p in "${patches[@]+"${patches[@]}"}"; do
    log "应用 patch：$(basename -- "${p}")"
    git -C "${KERNEL_DIR}" apply --whitespace=nowarn "${p}" \
      || die "patch 应用失败：${p}（用 --check 先定位冲突文件）"
  done
}

write_prep_info() {
  local npatches=$1
  local info="${KERNEL_DIR}/.cepheus-prep"
  local overlay_count=0
  [ -d "${OVERLAY_DIR}" ] && overlay_count=$(find "${OVERLAY_DIR}" -type f | wc -l | tr -d ' ')

  {
    printf 'prepared_at  = %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'kernel_head  = %s\n' "$(git -C "${KERNEL_DIR}" rev-parse HEAD)"
    printf 'overlay_files= %s\n' "${overlay_count}"
    printf 'patches      = %s\n' "${npatches}"
  } > "${info}"
  log "摘要写入 ${info}"
}

main "$@"
