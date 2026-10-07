#!/bin/zsh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
G3010_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

queue_name="${G3010_DEFAULT_QUEUE}"
printer_host=""
printer_uuid=""
printer_uri=""
explicit_host="no"
set_default="yes"
print_test_page="no"
dry_run="no"
force="no"
fetch_canon="yes"
accept_canon_license="no"
canon_dmg=""
offline="no"

usage() {
  cat <<EOF
Install Canon G3010 printer support on macOS.

Usage:
  ./scripts/install.sh [options]

Options:
  --host HOST              Printer hostname or IPv4
  --queue NAME             CUPS queue name (default: ${G3010_DEFAULT_QUEUE})
  --test                   Print a test page after install
  --no-default             Do not set as default printer
  --force                  Replace an existing queue
  --accept-canon-license   Allow downloading Canon's G3000 driver
  --canon-dmg PATH         Use a local Canon DMG
  --no-fetch-canon         Do not download Canon driver
  --offline                Same as --no-fetch-canon
  --dry-run                Show plan only
  -h, --help               Show help

Environment:
  G3010_DEBUG=1            Verbose logging
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --host)
      (( $# >= 2 )) || g3010_fail "--host requires a value"
      printer_host="$2"
      explicit_host="yes"
      shift 2
      ;;
    --queue)
      (( $# >= 2 )) || g3010_fail "--queue requires a value"
      queue_name="$2"
      shift 2
      ;;
    --test)
      print_test_page="yes"
      shift
      ;;
    --no-default)
      set_default="no"
      shift
      ;;
    --force)
      force="yes"
      shift
      ;;
    --accept-canon-license)
      accept_canon_license="yes"
      shift
      ;;
    --canon-dmg)
      (( $# >= 2 )) || g3010_fail "--canon-dmg requires a path"
      canon_dmg="$2"
      shift 2
      ;;
    --no-fetch-canon|--offline)
      fetch_canon="no"
      offline="yes"
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

version="$(g3010_version)"
g3010_info "${G3010_PROJECT_NAME} v${version}"
g3010_info "Architecture: $(g3010_arch)"

if g3010_canon_driver_installed; then
  g3010_info "Canon G3000 driver: found"
elif [[ "${fetch_canon}" == "yes" ]]; then
  g3010_info "Canon G3000 driver: downloading"
  ensure_args=(--accept-canon-license)
  if [[ "${accept_canon_license}" != "yes" && -t 0 ]]; then
    ensure_args=()
  elif [[ "${accept_canon_license}" != "yes" ]]; then
    g3010_fail "Canon driver missing. Re-run with --accept-canon-license"
  fi
  [[ -n "${canon_dmg}" ]] && ensure_args+=(--dmg "${canon_dmg}")
  [[ "${offline}" == "yes" ]] && ensure_args+=(--offline)
  [[ "${dry_run}" == "yes" ]] && ensure_args+=(--dry-run)
  "${SCRIPT_DIR}/ensure-canon-driver.sh" "${ensure_args[@]}"
  if [[ "${dry_run}" == "yes" ]]; then
    g3010_info "Dry run complete"
    exit 0
  fi
  g3010_canon_driver_installed || g3010_fail "Canon driver still missing"
  g3010_info "Canon G3000 driver: installed"
else
  g3010_require_canon_driver
fi

if [[ -z "${printer_host}" ]]; then
  g3010_info "Looking for '${G3010_DEFAULT_SERVICE_NAME}'"
  if g3010_discover; then
    printer_host="${G3010_DISCOVERED_HOST}"
    printer_uuid="${G3010_DISCOVERED_UUID}"
  else
    g3010_fail "Printer not found. Turn it on, join the same network, or use --host"
  fi
fi

if g3010_validate_ipv4 "${printer_host}"; then
  :
else
  g3010_validate_host "${printer_host}"
fi

printer_uri="$(g3010_build_uri "${printer_host}" "${printer_uuid}" "${explicit_host}")"

g3010_info "Queue:   ${queue_name}"
g3010_info "Printer: ${printer_host}"
g3010_info "URI:     ${printer_uri}"

if [[ "${dry_run}" == "yes" ]]; then
  g3010_info "Dry run complete"
  exit 0
fi

if g3010_queue_exists "${queue_name}"; then
  if [[ "${force}" != "yes" ]]; then
    g3010_fail "Queue '${queue_name}' already exists. Use --force or --queue NAME"
  fi
  g3010_info "Replacing queue '${queue_name}'"
  /usr/sbin/lpadmin -x "${queue_name}"
fi

g3010_info "Creating printer queue"
/usr/sbin/lpadmin \
  -p "${queue_name}" \
  -E \
  -v "${printer_uri}" \
  -m "${G3010_PPD_REL}" \
  -D "${G3010_DISPLAY_NAME}" \
  -L "Local Network" \
  -o printer-is-shared=false

/usr/bin/lpoptions \
  -p "${queue_name}" \
  -o PageSize=A4 \
  -o CNIJMediaType=0 \
  -o CNIJPrintQuality=10 \
  -o CNIJGrayScale=0 >/dev/null

if [[ "${set_default}" == "yes" ]]; then
  /usr/sbin/lpadmin -d "${queue_name}"
fi

support_dir="$(g3010_support_dir)"
/bin/mkdir -p "${support_dir}"
cat >"${support_dir}/queue.env" <<EOF
G3010_QUEUE=${queue_name}
G3010_HOST=${printer_host}
G3010_UUID=${printer_uuid}
G3010_URI=${printer_uri}
G3010_VERSION=${version}
G3010_INSTALLED_AT=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

g3010_info "Installed: ${G3010_DISPLAY_NAME}"
/usr/bin/lpstat -v "${queue_name}" || true

if [[ "${print_test_page}" == "yes" ]]; then
  [[ -f "${G3010_TEST_PAGE}" ]] ||
    g3010_fail "Test page missing: ${G3010_TEST_PAGE}"
  g3010_info "Sending test page"
  /usr/bin/lp \
    -d "${queue_name}" \
    -o PageSize=A4 \
    -o CNIJMediaType=0 \
    -o CNIJPrintQuality=10 \
    -o CNIJGrayScale=0 \
    "${G3010_TEST_PAGE}"
fi
