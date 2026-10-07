#!/bin/zsh
# Build GitHub Release assets for a public version tag.
# User ZIP contains only what Install.command needs (no Canon DMG, no build tree).
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="$(/usr/bin/tr -d '[:space:]' <"${ROOT}/VERSION")"
NAME="Canon-G3010-macOS-${VERSION}"
DIST="${ROOT}/dist"
STAGE="${ROOT}/build/release/${NAME}"

with_pkg="no"
while (( $# > 0 )); do
  case "$1" in
    --with-pkg) with_pkg="yes"; shift ;;
    -h|--help)
      print -- "Usage: ./packaging/build-release.sh [--with-pkg]"
      exit 0
      ;;
    *)
      print -u2 -- "Unknown option: $1"
      exit 1
      ;;
  esac
done

/bin/rm -rf "${ROOT}/build/release"
/bin/mkdir -p "${STAGE}/scripts/lib" "${STAGE}/docs" "${DIST}"

# --- User-facing payload (Install.command tree) ---
/bin/cp "${ROOT}/Install.command" "${STAGE}/"
/bin/cp "${ROOT}/VERSION" "${ROOT}/LICENSE" "${ROOT}/NOTICE.md" "${STAGE}/"
/bin/cp "${ROOT}/README.md" "${STAGE}/"
/bin/cp "${ROOT}/docs/troubleshooting.md" "${STAGE}/docs/"

/bin/cp \
  "${ROOT}/scripts/install.sh" \
  "${ROOT}/scripts/uninstall.sh" \
  "${ROOT}/scripts/ensure-canon-driver.sh" \
  "${ROOT}/scripts/g3010-doctor.sh" \
  "${ROOT}/scripts/test-print.sh" \
  "${STAGE}/scripts/"
/bin/cp "${ROOT}/scripts/lib/common.sh" "${STAGE}/scripts/lib/"

cat >"${STAGE}/INSTALL.txt" <<EOF
Canon PIXMA G3010 for macOS ${VERSION}
======================================

1. Keep the printer powered on and on the same Wi-Fi/LAN as this Mac.
2. Double-click Install.command
   If macOS blocks it: right-click Install.command → Open → Open
3. Press Return, then enter your Mac password when asked.
4. Open System Settings → Printers & Scanners

First install needs internet so Canon's G3000 CUPS driver can be
downloaded from Canon (about 15 MB). That DMG is not included here.

If discovery fails:
  ./scripts/install.sh --accept-canon-license --force --host PRINTER_IP

Diagnostics:
  ./scripts/g3010-doctor.sh
EOF

/bin/chmod 755 \
  "${STAGE}/Install.command" \
  "${STAGE}/scripts/"*.sh \
  "${STAGE}/scripts/lib/common.sh"

# Safety: never ship Canon binaries
if /usr/bin/find "${STAGE}" \( -name '*.dmg' -o -name '*PrinterDriver*' \) | /usr/bin/grep -q .; then
  print -u2 -- "Error: Canon artifacts found in staging area"
  exit 1
fi

# Fresh dist artifacts for this version
/bin/rm -f "${DIST}/${NAME}.zip" "${DIST}/${NAME}.pkg" \
  "${DIST}/SHA256SUMS-${VERSION}.txt" "${DIST}/GITHUB_RELEASE-${VERSION}.md"

# --- ZIP (no AppleDouble / __MACOSX clutter) ---
(
  cd "${ROOT}/build/release"
  COPYFILE_DISABLE=1 /usr/bin/zip -r -X "${DIST}/${NAME}.zip" "${NAME}"
)

# --- Optional .pkg (advanced / alternate asset) ---
if [[ "${with_pkg}" == "yes" ]]; then
  "${ROOT}/packaging/build-pkg.sh"
fi

# --- Checksums for published assets ---
SUMS="${DIST}/SHA256SUMS-${VERSION}.txt"
{
  /usr/bin/shasum -a 256 "${DIST}/${NAME}.zip" | /usr/bin/awk -v n="${NAME}.zip" '{print $1 "  " n}'
  if [[ -f "${DIST}/${NAME}.pkg" ]]; then
    /usr/bin/shasum -a 256 "${DIST}/${NAME}.pkg" | /usr/bin/awk -v n="${NAME}.pkg" '{print $1 "  " n}'
  fi
} >"${SUMS}"


# --- Release notes body for GitHub ---
NOTES="${DIST}/GITHUB_RELEASE-${VERSION}.md"
cat >"${NOTES}" <<EOF
## Canon PIXMA G3010 for macOS ${VERSION}

Unofficial macOS network printing support for the Canon PIXMA G3010.

### Install (recommended)

1. Download **${NAME}.zip**
2. Unzip it
3. Double-click **Install.command**
4. Enter your Mac password when asked

The printer should appear under **System Settings → Printers & Scanners**.

First install needs internet. The installer downloads Canon's official G3000 CUPS driver from Canon, verifies SHA-256, then sets up the G3010 queue. Canon's DMG is **not** included in this release.

### Verify download

\`\`\`sh
shasum -a 256 -c SHA256SUMS-${VERSION}.txt
\`\`\`

### If the printer is offline during install

\`\`\`sh
./scripts/install.sh --accept-canon-license --force --host PRINTER_IP
\`\`\`

### Requirements

- macOS 11+
- G3010 on the same Wi-Fi/LAN
- Internet on first install (~15 MB)
- Administrator password

### Assets

| File | Purpose |
|------|---------|
| \`${NAME}.zip\` | User installer (Install.command) |
| \`SHA256SUMS-${VERSION}.txt\` | Checksums |
| \`${NAME}.pkg\` | Optional alternate package (if published) |

Not affiliated with Canon.
EOF

print -- ""
print -- "Release assets in ${DIST}:"
/bin/ls -lh "${DIST}/${NAME}.zip" "${SUMS}" "${NOTES}"
[[ -f "${DIST}/${NAME}.pkg" ]] && /bin/ls -lh "${DIST}/${NAME}.pkg"
print -- ""
print -- "Upload to GitHub Release v${VERSION}:"
print -- "  - ${NAME}.zip"
print -- "  - SHA256SUMS-${VERSION}.txt"
[[ -f "${DIST}/${NAME}.pkg" ]] && print -- "  - ${NAME}.pkg (optional)"
print -- "Release body: ${NOTES}"
