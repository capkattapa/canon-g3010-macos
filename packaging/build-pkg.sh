#!/bin/zsh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="$(/usr/bin/tr -d '[:space:]' <"${ROOT}/VERSION")"
IDENTIFIER="org.community.canon-g3010-macos"
PKG_NAME="Canon-G3010-macOS-${VERSION}.pkg"

BUILD_DIR="${ROOT}/build/pkg"
STAGE="${BUILD_DIR}/stage"
SCRIPTS_STAGE="${BUILD_DIR}/scripts"
RES_STAGE="${BUILD_DIR}/resources"
DIST_DIR="${ROOT}/dist"

usage() {
  cat <<EOF
Build Canon-G3010-macOS-${VERSION}.pkg

Usage:
  ./packaging/build-pkg.sh [--sign IDENTITY]
EOF
}

sign_identity=""
while (( $# > 0 )); do
  case "$1" in
    --sign)
      (( $# >= 2 )) || { print -u2 "Error: --sign requires an identity"; exit 1; }
      sign_identity="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print -u2 "Error: unknown option: $1"
      exit 1
      ;;
  esac
done

[[ "$(/usr/bin/uname -s)" == "Darwin" ]] || {
  print -u2 "Error: packaging requires macOS"
  exit 1
}

/bin/rm -rf "${BUILD_DIR}"
/bin/mkdir -p \
  "${STAGE}/usr/local/libexec/canon-g3010-macos/scripts/lib" \
  "${STAGE}/usr/local/bin" \
  "${SCRIPTS_STAGE}" \
  "${RES_STAGE}" \
  "${DIST_DIR}"

/bin/cp "${ROOT}/VERSION" "${ROOT}/LICENSE" "${ROOT}/NOTICE.md" \
  "${STAGE}/usr/local/libexec/canon-g3010-macos/"
/bin/cp "${ROOT}/scripts/lib/common.sh" \
  "${STAGE}/usr/local/libexec/canon-g3010-macos/scripts/lib/"
/bin/cp \
  "${ROOT}/scripts/install.sh" \
  "${ROOT}/scripts/uninstall.sh" \
  "${ROOT}/scripts/g3010-doctor.sh" \
  "${ROOT}/scripts/test-print.sh" \
  "${ROOT}/scripts/ensure-canon-driver.sh" \
  "${STAGE}/usr/local/libexec/canon-g3010-macos/scripts/"

/bin/chmod 755 \
  "${STAGE}/usr/local/libexec/canon-g3010-macos/scripts/"*.sh \
  "${STAGE}/usr/local/libexec/canon-g3010-macos/scripts/lib/common.sh"

for pair in \
  "g3010-install:install.sh" \
  "g3010-uninstall:uninstall.sh" \
  "g3010-doctor:g3010-doctor.sh" \
  "g3010-test-print:test-print.sh" \
  "g3010-ensure-canon:ensure-canon-driver.sh"
do
  dest="${pair%%:*}"
  src="${pair#*:}"
  cat >"${STAGE}/usr/local/bin/${dest}" <<EOF
#!/bin/zsh
exec /usr/local/libexec/canon-g3010-macos/scripts/${src} "\$@"
EOF
  /bin/chmod 755 "${STAGE}/usr/local/bin/${dest}"
done

cat >"${RES_STAGE}/welcome.txt" <<EOF
Canon PIXMA G3010 macOS Compatibility ${VERSION}

Installs printer support for the Canon PIXMA G3010 on this Mac.

The printer should be on the same network. The first install needs internet
to download Canon's G3000 CUPS driver from Canon (about 15 MB).
EOF

cat >"${RES_STAGE}/license.txt" <<EOF
This installer (MIT license) may download and install Canon's G3000 CUPS
Printer Driver from Canon. Canon's software remains under Canon's license.

https://asia.canon/en/support/0101155813?model=PIXMA%20G3000

Agreeing continues installation of both components.
EOF

cat >"${SCRIPTS_STAGE}/postinstall" <<'EOF'
#!/bin/zsh
set -eu

LIBEXEC="/usr/local/libexec/canon-g3010-macos"
INSTALL="${LIBEXEC}/scripts/install.sh"
LOG="/var/log/canon-g3010-macos-postinstall.log"

{
  /bin/echo "=== Canon G3010 macOS Compatibility postinstall $(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

  /usr/sbin/chown -R root:wheel "${LIBEXEC}" /usr/local/bin/g3010-* 2>/dev/null || true
  /bin/chmod 755 "${LIBEXEC}/scripts/"*.sh /usr/local/bin/g3010-* 2>/dev/null || true

  if [[ ! -x "${INSTALL}" ]]; then
    /bin/echo "ERROR: install helper missing"
    exit 0
  fi

  if "${INSTALL}" --force --accept-canon-license >>"${LOG}" 2>&1; then
    /bin/echo "Printer configured."
  else
    /bin/echo "Tools installed. If setup is incomplete, see ${LOG}"
    /bin/echo "Then run: g3010-install --force --accept-canon-license"
  fi
} | /usr/bin/tee -a "${LOG}" >/dev/null

exit 0
EOF
/bin/chmod 755 "${SCRIPTS_STAGE}/postinstall"

COMPONENT="${BUILD_DIR}/Canon-G3010-macOS-component.pkg"
/usr/bin/pkgbuild \
  --root "${STAGE}" \
  --scripts "${SCRIPTS_STAGE}" \
  --identifier "${IDENTIFIER}" \
  --version "${VERSION}" \
  --install-location / \
  "${COMPONENT}"

DIST_XML="${BUILD_DIR}/distribution.xml"
cat >"${DIST_XML}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Canon G3010 macOS Compatibility</title>
  <organization>org.community</organization>
  <domains enable_localSystem="true"/>
  <options customize="never" require-scripts="true" rootVolumeOnly="true"/>
  <welcome file="welcome.txt"/>
  <license file="license.txt"/>
  <pkg-ref id="${IDENTIFIER}"/>
  <choices-outline>
    <line choice="default"/>
  </choices-outline>
  <choice id="default" title="Install">
    <pkg-ref id="${IDENTIFIER}"/>
  </choice>
  <pkg-ref id="${IDENTIFIER}" version="${VERSION}" onConclusion="none">Canon-G3010-macOS-component.pkg</pkg-ref>
</installer-gui-script>
EOF

if [[ -n "${sign_identity}" ]]; then
  /usr/bin/productbuild \
    --distribution "${DIST_XML}" \
    --resources "${RES_STAGE}" \
    --package-path "${BUILD_DIR}" \
    --sign "${sign_identity}" \
    "${DIST_DIR}/${PKG_NAME}"
else
  /usr/bin/productbuild \
    --distribution "${DIST_XML}" \
    --resources "${RES_STAGE}" \
    --package-path "${BUILD_DIR}" \
    "${DIST_DIR}/${PKG_NAME}"
  print -- "Unsigned. Sign with: ./packaging/build-pkg.sh --sign \"Developer ID Installer: …\""
fi

print -- "Built ${DIST_DIR}/${PKG_NAME}"
/bin/ls -lh "${DIST_DIR}/${PKG_NAME}"
