#!/usr/bin/env bash
# install.sh — Install Dockman by creating a symlink in /usr/local/bin.
# The project directory is used in-place; editing the source takes effect immediately.
set -e

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_SRC="$SCRIPT_DIR/bin/dockman"
BIN_LINK="$INSTALL_DIR/dockman"

if [[ ! -x "$BIN_SRC" ]]; then
  chmod +x "$BIN_SRC"
fi

if [[ -e "$BIN_LINK" || -L "$BIN_LINK" ]]; then
  echo "Removing existing $BIN_LINK"
  rm -f "$BIN_LINK"
fi

ln -s "$BIN_SRC" "$BIN_LINK"
echo "Installed: $BIN_LINK -> $BIN_SRC"
echo "Run 'dockman' to start."
