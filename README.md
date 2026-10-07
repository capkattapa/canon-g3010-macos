# Canon PIXMA G3010 for macOS

Unofficial macOS installer for network printing to a Canon PIXMA G3010.

This project is not affiliated with Canon. The installer downloads Canon’s official G3000 CUPS driver from Canon when needed. Canon files are not included in this repository.

## Install

### Package (recommended)

1. Download `Canon-G3010-macOS-*.pkg` from [Releases](../../releases).
2. Open the package and follow the prompts.
3. Enter your Mac password when asked.

The printer should appear under **System Settings → Printers & Scanners**.

If the printer was offline during install:

```sh
g3010-install --force --accept-canon-license
```

Or with a known address:

```sh
g3010-install --force --accept-canon-license --host 192.168.0.50
```

### From source

In Finder, double-click `Install.command`.

Or in Terminal:

```sh
./Install.command
```

## Requirements

- macOS 11 or later
- Canon PIXMA G3010 on the same Wi‑Fi or LAN
- Internet on first install (Canon driver download, about 15 MB)
- Administrator password

## Commands

| Command | Description |
|---------|-------------|
| `g3010-install` | Install or repair the printer setup |
| `g3010-doctor` | Check the installation |
| `g3010-test-print` | Print a test page |
| `g3010-uninstall` | Remove the printer queue |
| `g3010-ensure-canon` | Install only the Canon G3000 driver |

## Build the package

```sh
make pkg
```

Output: `dist/Canon-G3010-macOS-<version>.pkg`

To sign:

```sh
./packaging/build-pkg.sh --sign "Developer ID Installer: Your Name (TEAMID)"
```

Do not attach Canon `.dmg` files to GitHub releases. The installer downloads them from Canon.

## How it works

```text
App → CUPS → Canon G3000 renderer (BJRaster3) → LPD/Bonjour → G3010
```

## Offline install

1. Download the G3000 CUPS driver DMG from [Canon](https://asia.canon/en/support/0101155813?model=PIXMA%20G3000).
2. Run:

```sh
g3010-install --accept-canon-license --canon-dmg /path/to/mcpd-mac-g3000-16_91_0_0-ea21_3.dmg
```

## Uninstall

```sh
g3010-uninstall
```

This removes the G3010 queue created by this project. Canon’s G3000 driver is left installed.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).

```sh
g3010-doctor
```

## License

MIT for this repository. Canon software remains under Canon’s terms. See [NOTICE.md](NOTICE.md).
