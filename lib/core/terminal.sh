#!/usr/bin/env bash
# core/terminal.sh — ANSI colors, cursor control, screen utilities.
# No dependencies on other layers.

# ---------- colors ----------
if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
else
  RESET=''; BOLD=''; DIM=''; CYAN=''; GREEN=''; YELLOW=''; RED=''
fi

# ---------- terminal lifecycle ----------
cleanup_terminal() {
  printf '\033[?25h%b' "$RESET"
}
trap cleanup_terminal EXIT
trap 'cleanup_terminal; exit 130' INT TERM

# ---------- screen ----------
screen_clear() {
  printf '\033[2J\033[H'
}

cursor_home() {
  printf '\033[H'
}

hide_cursor() { printf '\033[?25l'; }
show_cursor()  { printf '\033[?25h'; }

pause_screen() {
  echo
  read -r -p "Press Enter to return..." _
}

# ---------- header ----------
# header TITLE [SUBTITLE]
# Reads RESOURCE_SUMMARY if set.
header() {
  local title="$1"
  local subtitle="${2:-}"
  printf '%b%b%s%b' "$CYAN" "$BOLD" "$title" "$RESET"
  if [[ -n "$subtitle" ]]; then
    printf '  %b%s%b' "$DIM" "$subtitle" "$RESET"
  fi
  printf '\n'
  if [[ -n "${RESOURCE_SUMMARY:-}" ]]; then
    printf '%b%s%b\n' "$DIM" "$RESOURCE_SUMMARY" "$RESET"
  fi
  printf '\n'
}

# ---------- footer ----------
# Reads MENU_ALLOW_BACK if set.
footer() {
  if [[ "${MENU_ALLOW_BACK:-1}" -eq 1 ]]; then
    printf '\n%b  ↑↓: Navigate  •  →/Enter: Select  •  ←/Esc: Back  •  Q: Quit%b\n' "$DIM" "$RESET"
  else
    printf '\n%b  ↑↓: Navigate  •  →/Enter: Select  •  Q: Quit%b\n' "$DIM" "$RESET"
  fi
}

# ---------- error ----------
die() {
  printf '%bError:%b %s\n' "$RED$BOLD" "$RESET" "$1" >&2
  exit 1
}
