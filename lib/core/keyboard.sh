#!/usr/bin/env bash
# core/keyboard.sh — Raw keyboard input, escape-sequence parsing.
# Depends on: nothing (core only).

KEY=""

# Read one optional byte with a 0.1 s terminal-level timeout.
# `stty time` is in tenths of a second — compatible with Bash 3.2.
read_escape_byte() {
  local saved byte
  saved="$(stty -g 2>/dev/null)" || return 1
  stty -echo -icanon min 0 time 1 2>/dev/null || return 1
  byte="$(dd bs=1 count=1 2>/dev/null)"
  stty "$saved" 2>/dev/null || true
  [[ -n "$byte" ]] || return 1
  printf '%s' "$byte"
}

# Read one keypress and store the result in KEY.
# Recognized values: UP DOWN ENTER ESC QUIT, or the raw character.
read_key() {
  local k="" k2="" k3=""
  IFS= read -rsn1 k || true
  case "$k" in
    $'\033')
      k2="$(read_escape_byte || true)"
      if [[ "$k2" == "[" || "$k2" == "O" ]]; then
        k3="$(read_escape_byte || true)"
        case "$k3" in
          A) KEY="UP"    ;;
          B) KEY="DOWN"  ;;
          C) KEY="ENTER" ;;  # Right arrow → open/select
          D) KEY="ESC"   ;;  # Left arrow  → back
          *) KEY="ESC"   ;;
        esac
      else
        KEY="ESC"
      fi
      ;;
    "")  KEY="ENTER" ;;
    j|J) KEY="DOWN"  ;;
    k|K) KEY="UP"    ;;
    q|Q) KEY="QUIT"  ;;
    *)   KEY="$k"    ;;
  esac
}
