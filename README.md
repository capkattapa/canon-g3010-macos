# Canon PIXMA G3010 for macOS

Unofficial macOS installer for network printing to a Canon PIXMA G3010.

Not affiliated with Canon. The installer downloads Canon’s official G3000 CUPS driver from Canon when needed. Canon’s DMG is not included in this project or in release downloads.

## Install (recommended)

1. Download **`Canon-G3010-macOS-1.1.0.zip`** from [Releases](../../releases).
2. Unzip the file.
3. Double-click **`Install.command`**.
4. Press Return, then enter your Mac password when asked.

The printer should appear under **System Settings → Printers & Scanners**.

First install needs internet (about 15 MB) so Canon’s G3000 driver can be fetched from Canon and checked with SHA-256 before installation.

If the printer was offline during install:

```sh
./scripts/install.sh --accept-canon-license --force --host 192.168.0.50
```

### Verify the release download

```sh
shasum -a 256 -c SHA256SUMS-1.1.0.txt
```

## Requirements

- macOS 11 or later
- Canon PIXMA G3010 on the same Wi‑Fi or LAN
- Internet on first install
- Administrator password

## After install

| Command | Description |
|---------|-------------|
| `./scripts/g3010-doctor.sh` | Check the setup |
| `./scripts/test-print.sh` | Print a test page |
| `./scripts/uninstall.sh` | Remove the printer queue |

From a full package install (`make pkg`), the same tools are also available as `g3010-doctor`, `g3010-test-print`, and `g3010-uninstall`.

## How it works

```text
App → CUPS → Canon G3000 renderer (BJRaster3) → LPD/Bonjour → G3010
```

## Offline install

1. Download the G3000 CUPS driver DMG from [Canon](https://asia.canon/en/support/0101155813?model=PIXMA%20G3000).
2. Run:

```sh
./scripts/install.sh --accept-canon-license --canon-dmg /path/to/mcpd-mac-g3000-16_91_0_0-ea21_3.dmg
```

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).

```sh
./scripts/g3010-doctor.sh
```

## How it works

```text
App → CUPS → Canon G3000 renderer (BJRaster3) → LPD/Bonjour → G3010
```

## For developers

Clone this repository for source, packaging, and CI. Ordinary users only need the release ZIP.

```sh
make check
make release          # user ZIP + checksums + release notes
make release-pkg      # above, plus optional .pkg
```

Do not attach Canon `.dmg` files to GitHub releases.

## License

MIT for this repository. Canon software remains under Canon’s terms. See [NOTICE.md](NOTICE.md).
