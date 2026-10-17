#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# fetch-sources.sh — 拉取 cepheus GKI 项目所需的源码。
#
# 用途：在 Linux（CI runner / WSL2）上把 ACK 底板与 CAF techpack 拉到工作区，
#       并记录每个仓库的 HEAD SHA（PINS.txt），保证构建可复现。
#
# 注意：本脚本只负责“取到并检出”，**不做 in-tree 集成**。
#       techpack 的 Makefile/Kconfig 接入属于移植提交（见 docs/roadmap.md S1）。
#
# 用法：
#   scripts/fetch-sources.sh [--check]
#
# 主要环境变量（均可省略，括号内为默认值）：
#   KERNEL_DIR   (src/kernel)                 ACK 内核树落地目录
#   TECH_DIR     (src/techpack)               techpack staging 目录
#   ACK_REPO     (https://github.com/aosp-mirror/kernel_common)
#   ACK_BRANCH   (android12-5.10)
#   ACK_SHA      ()                           指定则检出该 commit（推荐用于复现）
#   TECH_REQUIRED(0)                          1 = techpack 拉取失败即退出
#   TECH_RETRIES (3)
#
# 退出码：0 成功（techpack 失败但 TECH_REQUIRED=0 时仍为 0，并给出警告）

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

KERNEL_DIR=${KERNEL_DIR:-${REPO_ROOT}/src/kernel}
TECH_DIR=${TECH_DIR:-${REPO_ROOT}/src/techpack}
ACK_REPO=${ACK_REPO:-https://github.com/aosp-mirror/kernel_common}
ACK_BRANCH=${ACK_BRANCH:-android12-5.10}
ACK_SHA=${ACK_SHA:-}
TECH_REQUIRED=${TECH_REQUIRED:-0}
TECH_RETRIES=${TECH_RETRIES:-3}

CAF_BASE=${CAF_BASE:-https://git.codelinaro.org/clo/la/platform/vendor/opensource}

# techpack staging 清单：目录名 -> 仓库 URL
# 分支名通过 TECH_BRANCH_<KEY> 覆盖；默认值待 S1 用 GitLab API 实测确认（见 D006 / R10）。
tech_names=(display-drivers audio-kernel camera-kernel video-driver)
declare -A TECH_URL=(
  [display-drivers]="${CAF_BASE}/display-drivers"
  [audio-kernel]="${CAF_BASE}/audio-kernel"
  [camera-kernel]="${CAF_BASE}/camera-kernel"
  [video-driver]="${CAF_BASE}/video-driver"
)
declare -A TECH_BRANCH=(
  [display-drivers]="${TECH_BRANCH_DISPLAY:-display-kernel.lnx.5.10.r8-rel}"
  [audio-kernel]="${TECH_BRANCH_AUDIO:-}"
  [camera-kernel]="${TECH_BRANCH_CAMERA:-}"
  [video-driver]="${TECH_BRANCH_VIDEO:-}"
)
# 每个 techpack 对应的环境变量名（用于提示，避免用户猜变量名）
declare -A TECH_BRANCH_VAR=(
  [display-drivers]=TECH_BRANCH_DISPLAY
  [audio-kernel]=TECH_BRANCH_AUDIO
  [camera-kernel]=TECH_BRANCH_CAMERA
  [video-driver]=TECH_BRANCH_VIDEO
)

CHECK_ONLY=0
failed_tech=()

log()  { printf '[fetch] %s\n' "$*"; }
warn() { printf '[fetch] WARN: %s\n' "$*" >&2; }
die()  { printf '[fetch] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

main() {
  case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) die "未知参数：$1（可用：--check, --help）" ;;
  esac

  command -v git >/dev/null 2>&1 || die "未找到 git"

  log "ACK_REPO   = ${ACK_REPO}"
  log "ACK_BRANCH = ${ACK_BRANCH}"
  log "ACK_SHA    = ${ACK_SHA:-<branch HEAD>}"
  log "KERNEL_DIR = ${KERNEL_DIR}"
  log "TECH_DIR   = ${TECH_DIR}"

  if [ "${CHECK_ONLY}" -eq 1 ]; then
    log "--check 模式：仅校验参数与环境，不做网络操作"
    [ -n "${ACK_REPO}" ]   || die "ACK_REPO 为空"
    [ -n "${ACK_BRANCH}" ] || die "ACK_BRANCH 为空"
    for name in "${tech_names[@]}"; do
      if [ -z "${TECH_BRANCH[${name}]}" ]; then
        warn "techpack ${name} 未指定分支（${TECH_BRANCH_VAR[${name}]}），运行时会跳过"
      fi
    done
    log "--check 通过"
    return 0
  fi

  fetch_ack
  fetch_techpack
  write_pins

  if [ "${#failed_tech[@]}" -gt 0 ]; then
    warn "以下 techpack 未取到：${failed_tech[*]}"
    warn "确认分支名后重跑（TECH_BRANCH_* 覆盖），或设 TECH_REQUIRED=1 使其成为硬失败"
    if [ "${TECH_REQUIRED}" -eq 1 ]; then
      die "TECH_REQUIRED=1 且存在失败的 techpack"
    fi
  fi

  log "完成"
}

# git clone 带重试：不稳定网络下先删半成品再重试
clone_with_retry() {
  local dir=$1; shift
  local attempt
  for attempt in $(seq 1 "${TECH_RETRIES}"); do
    rm -rf -- "${dir}"
    if git -c http.version=HTTP/1.1 clone --depth 1 --single-branch "$@" "${dir}"; then
      return 0
    fi
    warn "clone 失败（第 ${attempt}/${TECH_RETRIES} 次）：$*"
    sleep $((attempt * 5))
  done
  return 1
}

fetch_ack() {
  if [ -d "${KERNEL_DIR}/.git" ]; then
    log "ACK 树已存在，跳过 clone：${KERNEL_DIR}"
  else
    log "拉取 ACK：${ACK_REPO} (${ACK_BRANCH})"
    mkdir -p -- "$(dirname -- "${KERNEL_DIR}")"
    clone_with_retry "${KERNEL_DIR}" --branch "${ACK_BRANCH}" "${ACK_REPO}" \
      || die "ACK 拉取失败（本地网络对 ~200MB pack 不稳定时，请改用 CI：bootstrap-sources.yml）"
  fi

  if [ -n "${ACK_SHA}" ]; then
    log "检出指定 commit：${ACK_SHA}"
    git -C "${KERNEL_DIR}" fetch --depth 1 origin "${ACK_SHA}" || die "获取 ${ACK_SHA} 失败"
    git -C "${KERNEL_DIR}" checkout --detach "${ACK_SHA}"
  fi

  verify_ack_version
}

# 校验内核版本确为 5.10，防止拉错分支/镜像滞后带来的静默错误
verify_ack_version() {
  local makefile="${KERNEL_DIR}/Makefile"
  [ -f "${makefile}" ] || die "未找到 ${makefile}，内核树不完整"

  local version patchlevel
  version=$(awk -F' = ' '/^VERSION =/{print $2}' "${makefile}")
  patchlevel=$(awk -F' = ' '/^PATCHLEVEL =/{print $2}' "${makefile}")

  [ "${version}" = "5" ] || die "内核主版本为 ${version}，期望 5（ACK_BRANCH=${ACK_BRANCH}）"
  [ "${patchlevel}" = "10" ] || die "内核次版本为 ${patchlevel}，期望 10（ACK_BRANCH=${ACK_BRANCH}）"
  log "内核版本校验通过：5.${patchlevel}"
}

fetch_techpack() {
  mkdir -p -- "${TECH_DIR}"
  local name branch
  for name in "${tech_names[@]}"; do
    branch=${TECH_BRANCH[${name}]}
    if [ -z "${branch}" ]; then
      warn "跳过 ${name}：分支名未确认（见 memory/OPEN.md R10）"
      failed_tech+=("${name}(未指定分支)")
      continue
    fi
    if [ -d "${TECH_DIR}/${name}/.git" ]; then
      log "techpack 已存在，跳过：${name}"
      continue
    fi
    log "拉取 techpack：${name} (${branch})"
    if clone_with_retry "${TECH_DIR}/${name}" --branch "${branch}" "${TECH_URL[${name}]}"; then
      :
    else
      failed_tech+=("${name}")
    fi
  done
}

write_pins() {
  local pins="${TECH_DIR}/PINS.txt"
  mkdir -p -- "${TECH_DIR}"
  {
    printf '# 由 scripts/fetch-sources.sh 生成，%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'ack %s %s %s\n' "${ACK_REPO}" "${ACK_BRANCH}" \
      "$(git -C "${KERNEL_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
    local name
    for name in "${tech_names[@]}"; do
      if [ -d "${TECH_DIR}/${name}/.git" ]; then
        printf 'techpack/%s %s %s %s\n' "${name}" "${TECH_URL[${name}]}" \
          "$(git -C "${TECH_DIR}/${name}" rev-parse --abbrev-ref HEAD)" \
          "$(git -C "${TECH_DIR}/${name}" rev-parse HEAD)"
      fi
    done
  } > "${pins}"
  log "PINS 已写入 ${pins}"
}

main "$@"
