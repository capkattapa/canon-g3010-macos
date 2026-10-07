#!/bin/zsh
exec "$(cd "$(dirname "$0")" && pwd)/scripts/install.sh" "$@"
