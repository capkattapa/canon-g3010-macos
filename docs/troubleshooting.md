# Troubleshooting

## Driver missing

```sh
g3010-install --force --accept-canon-license
```

Needs internet, or pass a local Canon DMG:

```sh
g3010-install --accept-canon-license --canon-dmg /path/to/file.dmg
```

## Printer not found

- Confirm the printer is on and joined to the same network as the Mac
- Avoid the printer’s own SoftAP unless you meant to use it
- Try a direct address:

```sh
g3010-install --force --accept-canon-license --host PRINTER_IP
```

## Nothing prints

```sh
lpstat -p Canon_G3010 -l
g3010-doctor
g3010-test-print --system
```

If you added an IPP Everywhere / AirPrint queue yourself and jobs stall, remove that queue and use this installer instead.

## Permission errors

Use `Install.command` or:

```sh
sudo ./scripts/install.sh --accept-canon-license --force
```

## After uninstall, Canon software remains

Expected. Only the G3010 queue from this project is removed.
