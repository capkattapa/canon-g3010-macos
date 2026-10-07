#!/bin/zsh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
G3010_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

queue_name="${G3010_DEFAULT_QUEUE}"
keep_support="no"
dry_run="no"

usage() {
  cat <<EOF
Remove the G3010 printer queue created by this project.
Does not remove Canon's G3000 driver.

Usage:
  ./scripts/uninstall.sh [--queue NAME] [--keep-support] [--dry-run]
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --queue)
      (( $# >= 2 )) || g3010_fail "--queue requires a value"
      queue_name="$2"
      shift 2
      ;;
    --keep-support)
      keep_support="yes"
      shift
      ;;
    --dry-run)
      dry_run="yes"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      g3010_fail "unknown option: $1"
      ;;
  esac
done

g3010_require_macos
g3010_validate_token "queue name" "${queue_name}"

support_dir="$(g3010_support_dir)"

g3010_info "Uninstall plan:"
if g3010_queue_exists "${queue_name}"; then
  print -- "  - remove CUPS queue: ${queue_name}"
else
  print -- "  - CUPS queue ${queue_name}: not present"
fi
if [[ "${keep_support}" != "yes" && -d "${support_dir}" ]]; then
  print -- "  - remove support dir: ${support_dir}"
fi
print -- "  - Canon G3000 driver: kept"

if [[ "${dry_run}" == "yes" ]]; then
  g3010_info "Dry run complete"
  exit 0
fi

if g3010_queue_exists "${queue_name}"; then
  /usr/sbin/lpadmin -x "${queue_name}"
  g3010_info "Removed queue ${queue_name}"
else
  g3010_warn "Queue ${queue_name} was not installed"
fi

if [[ "${keep_support}" != "yes" && -d "${support_dir}" ]]; then
  /bin/rm -rf "${support_dir}"
  g3010_info "Removed ${support_dir}"
fi

g3010_info "Uninstall complete"
