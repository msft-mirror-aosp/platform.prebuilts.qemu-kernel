#!/bin/bash

# Examples:
# to update
# * modules only:
#   ./update_54_kernel.sh --bug 123 --goldfish_bid 6300759
# * the kernel file only (from common):
#   ./update_54_kernel.sh --bug 123 --kernel common --common_bid 6299923
# * modules and the kernel file (from common or goldfish):
#   ./update_54_kernel.sh --bug 123 --kernel common --goldfish_bid 6300759 --common_bid 6299923
#   ./update_54_kernel.sh --bug 123 --kernel goldfish --goldfish_bid 6300759 --common_bid 6299923

set -e
set -o errexit
source gbash.sh

DEFINE_int bug 0 "Bug with the reason for the update"
DEFINE_int goldfish_bid 0 "Build id for goldfish modules"
DEFINE_string kernel "none" "Choose where you want to fetch the kernel from, (common|goldfish|none)"
DEFINE_int common_bid 0 "Build id for the kernel binary (common)"
DEFINE_string goldfish_branch "aosp_kernel-r-goldfish-android-5.4" "'fetch_artifact branch' for goldfish modules"
DEFINE_string common_branch "aosp_kernel-common-android-5.4" "'fetch_artifact branch' for tke kernel binary"

fetch_arch() {
  scratch_dir="${1}"
  kernel_bid="${2}"
  kernel_branch="${3}"
  goldfish_bid="${4}"
  goldfish_branch="${5}"
  kernel_target="${6}"
  kernel_artifact="${7}"

  mkdir "${scratch_dir}"
  pushd "${scratch_dir}"

  if [[ "${kernel_bid}" -ne 0 ]]; then
    /google/data/ro/projects/android/fetch_artifact \
      --bid "${kernel_bid}" \
      --target "${kernel_target}" \
      --branch "${kernel_branch}" \
      "${kernel_artifact}"
  fi

  if [[ "${goldfish_bid}" -ne 0 ]]; then
    /google/data/ro/projects/android/fetch_artifact \
      --bid "${goldfish_bid}" \
      --target "${kernel_target}" \
      --branch "${goldfish_branch}" \
      "*.ko"
  fi

  popd
}

move_artifacts() {
  scratch_dir="${1}"
  dst_dir="${2}"
  kernel_artifact="${3}"
  goldfish_bid="${4}"

  pushd "${scratch_dir}"

  if [[ -f "${kernel_artifact}" ]]; then
    mv "${kernel_artifact}" "${dst_dir}/kernel-qemu2"
  fi

  if [[ "${goldfish_bid}" -ne 0 ]]; then
    rm -rf "${dst_dir}/ko-new"
    rm -rf "${dst_dir}/ko-old"
    mkdir "${dst_dir}/ko-new"
    mv *.ko "${dst_dir}/ko-new"
    mv "${dst_dir}/ko" "${dst_dir}/ko-old"
    mv "${dst_dir}/ko-new" "${dst_dir}/ko"
    rm -rf "${dst_dir}/ko-old"
  fi

  popd
}

main() {
  fail=0

  if [[ "${FLAGS_bug}" -eq 0 ]]; then
    echo Must specify --bug 1>&2
    fail=1
  fi

  kernel_bid="0"
  kernel_branch="empty"
  case "${FLAGS_kernel}" in
    common)
      if [[ "${FLAGS_common_bid}" -eq 0 ]]; then
        echo Must specify --common_bid 1>&2
        fail=1
      else
        kernel_bid=${FLAGS_common_bid}
        kernel_branch=${FLAGS_common_branch}
      fi
      ;;
    goldfish)
      if [[ "${FLAGS_goldfish_bid}" -eq 0 ]]; then
        echo Must specify --goldfish_bid 1>&2
        fail=1
      else
        kernel_bid=${FLAGS_goldfish_bid}
        kernel_branch=${FLAGS_goldfish_branch}
      fi
      ;;
    *)
      ;;
  esac

  if [[ "${fail}" -ne 0 ]]; then
    exit "${fail}"
  fi

  here="$(pwd)"
  x86_dst_dir="${here}/x86_64/5.4"
  arm_dst_dir="${here}/arm64/5.4"

  scratch_dir="$(mktemp -d)"
  x86_scratch_dir="${scratch_dir}/x86"
  arm_scratch_dir="${scratch_dir}/arm"

  fetch_arch "${x86_scratch_dir}" \
    "${kernel_bid}" "${kernel_branch}" \
    "${FLAGS_goldfish_bid}" "${FLAGS_goldfish_branch}" \
    "kernel_x86_64" "bzImage"

#  fetch_arch "${arm_scratch_dir}" \
#    "${kernel_bid}" "${kernel_branch}" \
#    "${FLAGS_goldfish_bid}" "${FLAGS_goldfish_branch}" \
#    "kernel_aarch64" "Image.gz"

  move_artifacts "${x86_scratch_dir}" "${x86_dst_dir}" "bzImage" "${FLAGS_goldfish_bid}"
#  move_artifacts "${arm_scratch_dir}" "${arm_dst_dir}" "Image.gz" "${FLAGS_goldfish_bid}"

  git add "${x86_dst_dir}"
#  git add "${arm_dst_dir}"

  if [[ "${FLAGS_goldfish_bid}" -ne 0 ]]; then
    git commit -a -m "$(
    echo Update kernel modules to ${FLAGS_goldfish_bid}
    echo
    echo kernel: ${kernel_branch}/${kernel_bid}
    echo modules: $FLAGS_goldfish_branch/$FLAGS_goldfish_bid
    echo
    echo Test: TreeHugger
    echo "Bug: ${FLAGS_bug}"
    )"
  else
    git commit -a -m "$(
    echo Update kernel to ${kernel_bid}
    echo
    echo kernel: ${kernel_branch}/${kernel_bid}
    echo
    echo Test: TreeHugger
    echo "Bug: ${FLAGS_bug}"
    )"
  fi

  git commit --amend -s
}

gbash::main "$@"

