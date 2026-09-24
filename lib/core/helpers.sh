#!/usr/bin/env bash
# core/helpers.sh — Shared utilities used by both docker and screens layers.
# Depends on: terminal.sh.

# confirm PROMPT
# Prompts the user for y/N confirmation. Returns 0 for yes, 1 for no.
confirm() {
  local prompt="$1" answer=""
  read -r -p "$prompt [y/N]: " answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# inspect_object KIND ID
# Displays `docker KIND inspect ID` output and waits for the user to return.
# KIND is one of: container, image, volume, network.
inspect_object() {
  local kind="$1" id="$2"
  screen_clear
  header "$id" "Docker $kind inspect"
  docker "$kind" inspect "$id" || true
  pause_screen
}
