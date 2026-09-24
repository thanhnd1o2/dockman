#!/usr/bin/env bash
# uninstall.sh — Remove Dockman from the system.
set -e

INSTALL_BIN="/usr/local/bin/dockman"
INSTALL_LIB="/usr/local/lib/dockman"

removed=0

if [[ -f "$INSTALL_BIN" || -L "$INSTALL_BIN" ]]; then
  rm -f "$INSTALL_BIN"
  echo "Removed: $INSTALL_BIN"
  removed=1
fi

if [[ -d "$INSTALL_LIB" ]]; then
  rm -rf "$INSTALL_LIB"
  echo "Removed: $INSTALL_LIB"
  removed=1
fi

if [[ "$removed" -eq 0 ]]; then
  echo "Dockman is not installed."
fi
