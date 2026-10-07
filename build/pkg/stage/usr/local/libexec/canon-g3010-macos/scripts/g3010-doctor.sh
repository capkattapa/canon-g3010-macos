#!/bin/zsh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
G3010_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

queue_name="${1:-${G3010_DEFAULT_QUEUE}}"
pass=0
fail=0
warn=0

section() {
  print -- ""
  print -- "--------------------------------"
  print -- "$*"
  print -- "--------------------------------"
}

check() {
  local label="$1"
  local result="$2"
  local detail="${3:-}"
  case "${result}" in
    PASS) pass=$((pass + 1)) ;;
    FAIL) fail=$((fail + 1)) ;;
    WARN) warn=$((warn + 1)) ;;
  esac
  printf '%-22s %-6s %s\n' "${label}" "${result}" "${detail}"
}

print -- "${G3010_PROJECT_NAME} Doctor"
print -- "Version: $(g3010_version)"
print -- "Generated: $(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"

section "System"
/usr/bin/sw_vers
print -- "Architecture: $(g3010_arch)"
if [[ "$(/usr/bin/uname -s)" == "Darwin" ]]; then
  check "macOS" "PASS"
else
  check "macOS" "FAIL" "not Darwin"
fi
case "$(g3010_arch)" in
  arm64) check "Apple Silicon" "PASS" ;;
  x86_64) check "Intel" "PASS" "x86_64" ;;
  *) check "Architecture" "WARN" "$(g3010_arch)" ;;
esac

section "CUPS / Bonjour"
if /usr/bin/lpstat -r >/dev/null 2>&1; then
  check "CUPS" "PASS" "$(/usr/sbin/cups-config --version 2>/dev/null || print -- present)"
else
  check "CUPS" "FAIL" "scheduler not running"
fi
if [[ -x /usr/bin/dns-sd ]]; then
  check "Bonjour" "PASS" "dns-sd"
else
  check "Bonjour" "FAIL" "dns-sd missing"
fi

section "Canon G3000 dependency"
if g3010_canon_driver_installed; then
  check "G3000 PPD" "PASS" "${G3010_PPD_PATH}"
  /usr/bin/gzip -dc "${G3010_PPD_PATH}" 2>/dev/null |
    /usr/bin/grep -E '^\*FileVersion:|^\*ModelName:|^\*cupsFilter:' |
    /usr/bin/head -n 8 || true
  if /usr/bin/gzip -dc "${G3010_PPD_PATH}" 2>/dev/null |
     /usr/bin/grep -q 'Raster2CanonIJS'; then
    check "Renderer filter" "PASS" "Raster2CanonIJS referenced in PPD"
  else
    check "Renderer filter" "WARN" "Raster2CanonIJS not found in PPD text"
  fi
else
  check "G3000 PPD" "FAIL" "missing"
  print -- "Fix: g3010-install --accept-canon-license"
  print -- "Or:  ${G3010_CANON_DOWNLOAD_URL}"
fi

section "G3010 discovery"
host=""
uuid=""
if g3010_discover; then
  host="${G3010_DISCOVERED_HOST}"
  uuid="${G3010_DISCOVERED_UUID}"
  check "G3010 Discovery" "PASS" "${host}"
  print -- "UUID: ${uuid:-unavailable}"
  print -- "Port (advertised): ${G3010_DISCOVERED_PORT:-unknown}"
else
  check "G3010 Discovery" "FAIL" "Bonjour service not found"
  print -- "Ensure the printer is on, Wi‑Fi connected, and Bonjour is enabled."
fi

section "Network protocols"
if [[ -n "${host}" ]]; then
  for port_label in "80:HTTP/WSD" "515:LPD" "631:IPP" "9100:RAW"; do
    port="${port_label%%:*}"
    label="${port_label#*:}"
    if g3010_probe_tcp "${host}" "${port}" 2; then
      check "${label} :${port}" "PASS" "open"
    else
      # LPD is required for the primary path
      if [[ "${port}" == "515" ]]; then
        check "${label} :${port}" "FAIL" "closed/unreachable"
      else
        check "${label} :${port}" "WARN" "closed/unreachable"
      fi
    fi
  done
else
  check "Network" "FAIL" "no host to probe"
fi

section "Driver installation"
if g3010_queue_exists "${queue_name}"; then
  check "CUPS queue" "PASS" "${queue_name}"
  /usr/bin/lpstat -p "${queue_name}" -l 2>/dev/null | /usr/bin/head -n 20 || true
  /usr/bin/lpstat -v "${queue_name}" 2>/dev/null || true
  /usr/bin/lpoptions -p "${queue_name}" 2>/dev/null |
    /usr/bin/tr ' ' '\n' |
    /usr/bin/grep -E '^(device-uri|printer-make-and-model|PageSize|CNIJMediaType|CNIJPrintQuality|CNIJGrayScale)=' ||
    true
else
  check "CUPS queue" "WARN" "${queue_name} not installed"
fi

support_dir="$(g3010_support_dir)"
if [[ -f "${support_dir}/queue.env" ]]; then
  check "Support state" "PASS" "${support_dir}/queue.env"
else
  check "Support state" "WARN" "no local install state"
fi

section "Summary"
printf '%-22s %s\n' "PASS" "${pass}"
printf '%-22s %s\n' "WARN" "${warn}"
printf '%-22s %s\n' "FAIL" "${fail}"
print -- ""
if (( fail == 0 )); then
  if [[ -n "${host}" ]]; then
    print -- "Printer: ${G3010_DEFAULT_SERVICE_NAME} (${host})"
  fi
  print -- "Status: OK"
  exit 0
fi
print -- "Status: needs attention"
exit 1
