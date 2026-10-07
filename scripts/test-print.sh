#!/bin/zsh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
G3010_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

queue_name="${G3010_DEFAULT_QUEUE}"
mode="color"
page_size="A4"
use_system_page="no"
keep_temp="no"

usage() {
  cat <<EOF
Print a test page to the G3010 queue.

Usage:
  ./scripts/test-print.sh [--queue NAME] [--grayscale] [--letter] [--system] [--keep]
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --queue)
      (( $# >= 2 )) || g3010_fail "--queue requires a value"
      queue_name="$2"
      shift 2
      ;;
    --grayscale)
      mode="grayscale"
      shift
      ;;
    --letter)
      page_size="Letter"
      shift
      ;;
    --system)
      use_system_page="yes"
      shift
      ;;
    --keep)
      keep_temp="yes"
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
g3010_queue_exists "${queue_name}" ||
  g3010_fail "Queue '${queue_name}' is not installed. Run ./scripts/install.sh first."

gray_opt=0
[[ "${mode}" == "grayscale" ]] && gray_opt=1

version="$(g3010_version)"
macos="$(/usr/bin/sw_vers -productVersion)"
arch="$(g3010_arch)"
uri="$(/usr/bin/lpstat -v "${queue_name}" 2>/dev/null | /usr/bin/awk '{print $3}')"

if [[ "${use_system_page}" == "yes" ]]; then
  [[ -f "${G3010_TEST_PAGE}" ]] ||
    g3010_fail "System test page missing: ${G3010_TEST_PAGE}"
  g3010_info "Sending system test page to ${queue_name}"
  /usr/bin/lp \
    -d "${queue_name}" \
    -o "PageSize=${page_size}" \
    -o CNIJMediaType=0 \
    -o CNIJPrintQuality=10 \
    -o "CNIJGrayScale=${gray_opt}" \
    "${G3010_TEST_PAGE}"
  exit 0
fi

tmp_ps="$(/usr/bin/mktemp -t g3010-test).ps"
tmp_pdf="${tmp_ps%.ps}.pdf"

cleanup() {
  if [[ "${keep_temp}" != "yes" ]]; then
    /bin/rm -f "${tmp_ps}" "${tmp_pdf}"
  else
    g3010_info "Kept ${tmp_pdf}"
  fi
}
trap cleanup EXIT

cat >"${tmp_ps}" <<EOF
%!PS-Adobe-3.0
%%Title: Canon G3010 macOS Compatibility Driver Test
%%Pages: 1
%%EndComments
/Helvetica findfont 16 scalefont setfont
72 720 moveto
(Canon G3010 macOS Compatibility Driver) show
/Helvetica findfont 11 scalefont setfont
72 690 moveto (Driver version: ${version}) show
72 674 moveto (macOS version: ${macos}) show
72 658 moveto (Architecture: ${arch}) show
72 642 moveto (Queue: ${queue_name}) show
72 626 moveto (URI: ${uri}) show
72 610 moveto (Protocol: LPD/Bonjour + BJRaster3 via G3000 renderer) show
72 594 moveto (Page size: ${page_size}) show
72 578 moveto (Color mode: ${mode}) show

72 540 moveto (Color test) show
1 0 0 setrgbcolor 72 510 120 24 rectfill
0 1 0 setrgbcolor 210 510 120 24 rectfill
0 0 1 setrgbcolor 348 510 120 24 rectfill

0 0 0 setrgbcolor
72 470 moveto (Black:) show
0 0 0 setrgbcolor 72 440 360 24 rectfill

72 400 moveto (Grayscale:) show
0.2 setgray 72 370 80 24 rectfill
0.4 setgray 160 370 80 24 rectfill
0.6 setgray 248 370 80 24 rectfill
0.8 setgray 336 370 80 24 rectfill

0 setgray
72 320 moveto (If this page prints, the CUPS → renderer → LPD path works.) show
showpage
%%EOF
EOF

if /usr/sbin/cupsfilter -m application/pdf "${tmp_ps}" >"${tmp_pdf}" 2>/dev/null; then
  :
elif command -v /usr/bin/pstopdf >/dev/null 2>&1; then
  /usr/bin/pstopdf "${tmp_ps}" -o "${tmp_pdf}" >/dev/null
else
  # Fall back to system test page if PDF conversion unavailable
  g3010_warn "Could not convert diagnostic PS; using system test page"
  /usr/bin/lp \
    -d "${queue_name}" \
    -o "PageSize=${page_size}" \
    -o CNIJMediaType=0 \
    -o CNIJPrintQuality=10 \
    -o "CNIJGrayScale=${gray_opt}" \
    "${G3010_TEST_PAGE}"
  exit 0
fi

g3010_info "Sending diagnostic test page (${mode}, ${page_size}) to ${queue_name}"
job="$(
  /usr/bin/lp \
    -d "${queue_name}" \
    -o "PageSize=${page_size}" \
    -o CNIJMediaType=0 \
    -o CNIJPrintQuality=10 \
    -o "CNIJGrayScale=${gray_opt}" \
    -t "G3010 compatibility test" \
    "${tmp_pdf}"
)"
print -- "${job}"
g3010_info "Watch the printer. Check status with: lpstat -p ${queue_name} -l"
