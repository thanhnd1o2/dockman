#!/usr/bin/env bash
# uninstall.sh — Remove the Dockman symlink from /usr/local/bin.
set -e

BIN_LINK="/usr/local/bin/dockman"

if [[ -L "$BIN_LINK" ]]; then
  rm -f "$BIN_LINK"
  echo "Removed: $BIN_LINK"
else
  echo "dockman is not installed at $BIN_LINK"
fi
