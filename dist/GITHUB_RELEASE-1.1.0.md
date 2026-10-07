## Canon PIXMA G3010 for macOS 1.1.0

Unofficial macOS network printing support for the Canon PIXMA G3010.

### Install (recommended)

1. Download **Canon-G3010-macOS-1.1.0.zip**
2. Unzip it
3. Double-click **Install.command**
4. Enter your Mac password when asked

The printer should appear under **System Settings → Printers & Scanners**.

First install needs internet. The installer downloads Canon's official G3000 CUPS driver from Canon, verifies SHA-256, then sets up the G3010 queue. Canon's DMG is **not** included in this release.

### Verify download

```sh
shasum -a 256 -c SHA256SUMS-1.1.0.txt
```

### If the printer is offline during install

```sh
./scripts/install.sh --accept-canon-license --force --host PRINTER_IP
```

### Requirements

- macOS 11+
- G3010 on the same Wi-Fi/LAN
- Internet on first install (~15 MB)
- Administrator password

### Assets

| File | Purpose |
|------|---------|
| `Canon-G3010-macOS-1.1.0.zip` | User installer (Install.command) |
| `SHA256SUMS-1.1.0.txt` | Checksums |
| `Canon-G3010-macOS-1.1.0.pkg` | Optional alternate package (if published) |

Not affiliated with Canon.
