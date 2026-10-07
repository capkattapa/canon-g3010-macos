#!/bin/zsh
# Double-click in Finder to install (opens Terminal).

set -u
cd "$(dirname "$0")" || exit 1

clear
echo "Canon G3010 macOS installer"
echo ""
echo "This will download Canon's G3000 driver if needed,"
echo "then add the G3010 printer in System Settings."
echo ""
echo "Printer should be on and on the same Wi-Fi/LAN."
echo ""
echo "Continuing accepts Canon's G3000 driver license"
echo "and the MIT license for this installer."
echo ""
printf "Press Return to continue (Ctrl+C to cancel): "
read -r _

echo ""
if [[ "$(/usr/bin/id -u)" -ne 0 ]]; then
  /usr/bin/sudo -v || {
    echo "Administrator password required."
    printf "Press Return to close: "
    read -r _
    exit 1
  }
fi

./scripts/install.sh --accept-canon-license --force
status=$?

echo ""
if (( status == 0 )); then
  echo "Done. Check System Settings → Printers & Scanners."
else
  echo "Install failed (exit ${status})."
  echo "Try: ./scripts/g3010-doctor.sh"
  echo "Or:  ./scripts/install.sh --accept-canon-license --force --host PRINTER_IP"
fi

echo ""
printf "Press Return to close: "
read -r _
exit "${status}"
