#!/bin/zsh
# Install Canon's G3000 CUPS driver (download from Canon if missing).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
G3010_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Official Canon artifact (G3000 series CUPS Printer Driver 16.91.0.0)
readonly CANON_DMG_NAME="mcpd-mac-g3000-16_91_0_0-ea21_3.dmg"
readonly CANON_DMG_SHA256="1df5efc4a0c736971d42da879fc7f38edd99dc0c4d171200ff834a7f10fe181c"
readonly CANON_DMG_SIZE_BYTES="16200882"
readonly CANON_DMG_URL_CDN="https://gdlp01.c-wss.com/gds/8/0100011558/06/${CANON_DMG_NAME}"
readonly CANON_DMG_URL_REDIRECT="https://pdisp01.c-wss.com/gdl/WWUFORedirectTarget.do?id=MDEwMDAxMTU1ODA2&cmp=ACB&lang=EN"
readonly CANON_SUPPORT_PAGE="${G3010_CANON_DOWNLOAD_URL}"

local_dmg=""
accept_license="no"
offline="no"
keep_dmg="no"
dry_run="no"

usage() {
  cat <<EOF
Install Canon's G3000 CUPS driver if it is not already present.

Usage:
  ./scripts/ensure-canon-driver.sh [options]

Options:
  --accept-canon-license   Required for non-interactive runs
  --dmg PATH               Use a local DMG
  --offline                Do not download
  --keep-dmg               Keep the downloaded DMG
  --dry-run                Show actions only
  -h, --help               Show help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --accept-canon-license) accept_license="yes"; shift ;;
    --dmg)
      (( $# >= 2 )) || g3010_fail "--dmg requires a path"
      local_dmg="$2"
      shift 2
      ;;
    --offline) offline="yes"; shift ;;
    --keep-dmg) keep_dmg="yes"; shift ;;
    --dry-run) dry_run="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) g3010_fail "unknown option: $1" ;;
  esac
done

g3010_require_macos

if g3010_canon_driver_installed; then
  g3010_info "Canon G3000 CUPS driver already present"
  print -- "${G3010_PPD_PATH}"
  exit 0
fi

if [[ "${accept_license}" != "yes" ]]; then
  print -- "This downloads Canon's G3000 CUPS driver from Canon."
  print -- "License: ${CANON_SUPPORT_PAGE}"
  if [[ -t 0 ]]; then
    print -n -- "Type YES to continue: "
    read -r answer
    [[ "${answer}" == "YES" ]] || g3010_fail "Cancelled"
    accept_license="yes"
  else
    g3010_fail "Pass --accept-canon-license for non-interactive install"
  fi
fi

cache_dir="$(g3010_support_dir)/cache"
/bin/mkdir -p "${cache_dir}"
dmg_path="${local_dmg}"

download_dmg() {
  local dest="$1"
  local url
  g3010_info "Downloading Canon G3000 driver (${CANON_DMG_NAME}, ~15 MB)"
  for url in "${CANON_DMG_URL_CDN}" "${CANON_DMG_URL_REDIRECT}"; do
    g3010_debug "GET ${url}"
    if /usr/bin/curl -fL --connect-timeout 30 --retry 3 --retry-delay 2 \
         -o "${dest}.partial" "${url}"; then
      /bin/mv -f "${dest}.partial" "${dest}"
      return 0
    fi
    /bin/rm -f "${dest}.partial"
  done
  return 1
}

verify_dmg() {
  local path="$1"
  local sum size
  [[ -f "${path}" ]] || return 1
  size="$(/usr/bin/stat -f%z "${path}")"
  if [[ "${size}" != "${CANON_DMG_SIZE_BYTES}" ]]; then
    g3010_warn "Unexpected DMG size: ${size} (expected ${CANON_DMG_SIZE_BYTES})"
  fi
  sum="$(/usr/bin/shasum -a 256 "${path}" | /usr/bin/awk '{print $1}')"
  if [[ "${sum}" != "${CANON_DMG_SHA256}" ]]; then
    g3010_fail "DMG checksum mismatch.
  got:      ${sum}
  expected: ${CANON_DMG_SHA256}
Refusing to install. Delete the cache file and retry, or pass --dmg PATH."
  fi
  g3010_info "Checksum OK (${sum})"
}

if [[ -z "${dmg_path}" ]]; then
  dmg_path="${cache_dir}/${CANON_DMG_NAME}"
  if [[ -f "${dmg_path}" ]]; then
    g3010_info "Using cached DMG: ${dmg_path}"
  else
    if [[ "${offline}" == "yes" ]]; then
      g3010_fail "Canon driver missing and --offline was set. Place the DMG at:
  ${dmg_path}
or pass --dmg PATH"
    fi
    if [[ "${dry_run}" == "yes" ]]; then
      g3010_info "Dry run: would download ${CANON_DMG_URL_CDN}"
      exit 0
    fi
    download_dmg "${dmg_path}" ||
      g3010_fail "Could not download Canon driver. Check internet access, or download manually:
  ${CANON_SUPPORT_PAGE}"
  fi
fi

[[ -f "${dmg_path}" ]] || g3010_fail "DMG not found: ${dmg_path}"

if [[ "${dry_run}" == "yes" ]]; then
  g3010_info "Dry run: would verify and install from ${dmg_path}"
  exit 0
fi

verify_dmg "${dmg_path}"

attach_out="$(/usr/bin/hdiutil attach "${dmg_path}" -nobrowse -readonly -mountrandom /tmp)"
g3010_debug "${attach_out}"
mount_point="$(print -- "${attach_out}" | /usr/bin/awk 'END { print $NF }')"
[[ -d "${mount_point}" ]] || g3010_fail "Failed to mount Canon DMG"

cleanup() {
  if [[ -n "${mount_point:-}" && -d "${mount_point}" ]]; then
    /usr/bin/hdiutil detach "${mount_point}" -quiet >/dev/null 2>&1 || true
  fi
  if [[ "${keep_dmg}" != "yes" && -z "${local_dmg}" && -f "${dmg_path}" ]]; then
    # Keep cache by default for reinstall speed; only delete with G3010_CLEAR_CACHE=1
    if [[ "${G3010_CLEAR_CACHE:-0}" == "1" ]]; then
      /bin/rm -f "${dmg_path}"
    fi
  fi
}
trap cleanup EXIT

canon_pkg="$(
  /usr/bin/find "${mount_point}" -name '*.pkg' -type f 2>/dev/null | /usr/bin/head -n 1
)"
[[ -n "${canon_pkg}" && -f "${canon_pkg}" ]] ||
  g3010_fail "No .pkg found inside Canon DMG"

g3010_info "Installing Canon package: ${canon_pkg:t}"
# installer requires root
if [[ "$(/usr/bin/id -u)" -ne 0 ]]; then
  /usr/bin/sudo /usr/sbin/installer -pkg "${canon_pkg}" -target /
else
  /usr/sbin/installer -pkg "${canon_pkg}" -target /
fi

g3010_canon_driver_installed ||
  g3010_fail "Canon installer finished but PPD is still missing:
  ${G3010_PPD_PATH}"

g3010_info "Canon G3000 CUPS driver installed successfully"
print -- "${G3010_PPD_PATH}"
