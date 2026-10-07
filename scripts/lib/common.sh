#!/bin/zsh
set -eu
set -o pipefail 2>/dev/null || true

readonly G3010_PROJECT_NAME="Canon G3010 macOS Compatibility"
readonly G3010_DEFAULT_QUEUE="Canon_G3010"
readonly G3010_DEFAULT_SERVICE_NAME="Canon G3010 series"
readonly G3010_DEFAULT_SERVICE_TYPE="_printer._tcp"
readonly G3010_DEFAULT_SERVICE_URI="Canon%20G3010%20series._printer._tcp.local."
readonly G3010_DISPLAY_NAME="Canon G3010 series"
readonly G3010_PPD_REL="Library/Printers/PPDs/Contents/Resources/CanonIJG3000series.ppd.gz"
readonly G3010_PPD_PATH="/${G3010_PPD_REL}"
readonly G3010_CANON_DOWNLOAD_URL="https://asia.canon/en/support/0101155813?model=PIXMA%20G3000"
readonly G3010_TEST_PAGE="/usr/share/cups/data/testprint"
readonly G3010_SUPPORT_DIR_NAME="Canon G3010 macOS Compatibility"

g3010_version() {
  local root version_file
  root="${G3010_ROOT:-}"
  if [[ -z "${root}" ]]; then
    root="$(cd "$(dirname "$0")/../.." && pwd 2>/dev/null || pwd)"
  fi
  version_file="${root}/VERSION"
  if [[ -f "${version_file}" ]]; then
    /usr/bin/tr -d '[:space:]' <"${version_file}"
  else
    print -- "unknown"
  fi
}

g3010_info() {
  print -- "==> $*"
}

g3010_warn() {
  print -u2 -- "Warning: $*"
}

g3010_fail() {
  print -u2 -- "Error: $*"
  exit 1
}

g3010_debug() {
  if [[ "${G3010_DEBUG:-0}" == "1" ]]; then
    print -u2 -- "[g3010-debug] $*"
  fi
}

g3010_require_macos() {
  [[ "$(/usr/bin/uname -s)" == "Darwin" ]] ||
    g3010_fail "This software supports macOS only."
}

g3010_arch() {
  /usr/bin/uname -m
}

g3010_validate_token() {
  local label="$1"
  local value="$2"
  if [[ ! "${value}" =~ '^[A-Za-z0-9._-]+$' ]]; then
    g3010_fail "${label} contains unsupported characters: ${value}"
  fi
}

g3010_validate_host() {
  local value="$1"
  if [[ ! "${value}" =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]]; then
    g3010_fail "Invalid printer host: ${value}"
  fi
}

g3010_validate_ipv4() {
  local value="$1"
  if [[ ! "${value}" =~ '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' ]]; then
    return 1
  fi
  local o
  for o in ${(s:.:)value}; do
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

g3010_canon_driver_installed() {
  [[ -f "${G3010_PPD_PATH}" ]]
}

g3010_require_canon_driver() {
  if ! g3010_canon_driver_installed; then
    print -u2 -- "Canon G3000 CUPS driver not found (${G3010_PPD_PATH})"
    print -u2 -- "Run: ./scripts/ensure-canon-driver.sh --accept-canon-license"
    print -u2 -- "Or download: ${G3010_CANON_DOWNLOAD_URL}"
    exit 3
  fi
}

g3010_queue_exists() {
  local queue="$1"
  /usr/bin/lpstat -p "${queue}" >/dev/null 2>&1
}

# Discover Bonjour identity for "Canon G3010 series"._printer._tcp
# Sets: G3010_DISCOVERED_HOST G3010_DISCOVERED_UUID G3010_DISCOVERED_PORT
g3010_discover() {
  local service_name="${1:-${G3010_DEFAULT_SERVICE_NAME}}"
  local service_type="${2:-${G3010_DEFAULT_SERVICE_TYPE}}"
  local lookup_file lookup_pid i

  G3010_DISCOVERED_HOST=""
  G3010_DISCOVERED_UUID=""
  G3010_DISCOVERED_PORT=""

  lookup_file="$(/usr/bin/mktemp -t g3010-dnssd)"
  g3010_debug "dns-sd -L '${service_name}' ${service_type} local."

  /usr/bin/dns-sd -L "${service_name}" "${service_type}" local. \
    >"${lookup_file}" 2>&1 &
  lookup_pid=$!

  for i in {1..12}; do
    if /usr/bin/grep -q "can be reached at" "${lookup_file}" 2>/dev/null; then
      break
    fi
    /bin/sleep 1
  done

  /bin/kill "${lookup_pid}" 2>/dev/null || true
  wait "${lookup_pid}" 2>/dev/null || true

  G3010_DISCOVERED_HOST="$(
    /usr/bin/sed -nE \
      's/.* can be reached at ([^: ]+):([0-9]+).*/\1/p' \
      "${lookup_file}" | /usr/bin/head -n 1
  )"
  G3010_DISCOVERED_PORT="$(
    /usr/bin/sed -nE \
      's/.* can be reached at ([^: ]+):([0-9]+).*/\2/p' \
      "${lookup_file}" | /usr/bin/head -n 1
  )"
  G3010_DISCOVERED_UUID="$(
    /usr/bin/sed -nE 's/.*(^|[[:space:]])UUID=([^[:space:]]+).*/\2/p' \
      "${lookup_file}" | /usr/bin/head -n 1
  )"

  g3010_debug "discovered host=${G3010_DISCOVERED_HOST} port=${G3010_DISCOVERED_PORT} uuid=${G3010_DISCOVERED_UUID}"
  /bin/rm -f "${lookup_file}"

  [[ -n "${G3010_DISCOVERED_HOST}" ]]
}

g3010_build_uri() {
  local host="$1"
  local uuid="${2:-}"
  local explicit="${3:-no}"

  if [[ "${explicit}" == "no" &&
        -n "${uuid}" &&
        "${uuid}" =~ '^[A-Fa-f0-9-]{32,36}$' ]]; then
    print -- "dnssd://${G3010_DEFAULT_SERVICE_URI}/?uuid=${uuid}"
  elif g3010_validate_ipv4 "${host}"; then
    print -- "lpd://${host}/auto"
  else
    g3010_validate_host "${host}"
    print -- "lpd://${host}/auto"
  fi
}

g3010_probe_tcp() {
  local host="$1"
  local port="$2"
  local timeout="${3:-2}"
  /usr/bin/nc -z -G "${timeout}" "${host}" "${port}" >/dev/null 2>&1
}

g3010_support_dir() {
  print -- "${HOME}/Library/Application Support/${G3010_SUPPORT_DIR_NAME}"
}
