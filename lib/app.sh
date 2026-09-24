#!/usr/bin/env bash
# app.sh — Bootstrap: loads all Dockman modules in dependency order.
# Requires DOCKMAN_ROOT to be set by the entry point.
# Load order: core → docker → screens.

# ---------- core ----------
source "$DOCKMAN_ROOT/lib/core/terminal.sh"
source "$DOCKMAN_ROOT/lib/core/keyboard.sh"
source "$DOCKMAN_ROOT/lib/core/menu.sh"
source "$DOCKMAN_ROOT/lib/core/helpers.sh"

# ---------- docker ----------
source "$DOCKMAN_ROOT/lib/docker/engine.sh"
source "$DOCKMAN_ROOT/lib/docker/containers.sh"
source "$DOCKMAN_ROOT/lib/docker/images.sh"
source "$DOCKMAN_ROOT/lib/docker/volumes.sh"
source "$DOCKMAN_ROOT/lib/docker/networks.sh"
source "$DOCKMAN_ROOT/lib/docker/ports.sh"

# ---------- screens ----------
source "$DOCKMAN_ROOT/lib/screens/containers.sh"
source "$DOCKMAN_ROOT/lib/screens/images.sh"
source "$DOCKMAN_ROOT/lib/screens/volumes.sh"
source "$DOCKMAN_ROOT/lib/screens/networks.sh"
source "$DOCKMAN_ROOT/lib/screens/system.sh"
source "$DOCKMAN_ROOT/lib/screens/cleanup.sh"
source "$DOCKMAN_ROOT/lib/screens/ports.sh"
source "$DOCKMAN_ROOT/lib/screens/root.sh"
