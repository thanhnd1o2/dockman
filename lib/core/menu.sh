#!/usr/bin/env bash
# core/menu.sh — Shared menu state, rendering, and navigation loop.
# Depends on: terminal.sh, keyboard.sh.

MENU_SELECTED=0
MENU_ALLOW_BACK=1

# draw_menu TITLE [SUBTITLE]
# Renders the current MENU_LABELS/MENU_DESCS list at the top of the screen.
# Callers must populate MENU_LABELS and MENU_DESCS before calling.
draw_menu() {
  local title="$1" subtitle="${2:-}" i prefix
  cursor_home
  header "$title" "$subtitle"
  for ((i=0; i<${#MENU_LABELS[@]}; i++)); do
    if [[ "$i" -eq "$MENU_SELECTED" ]]; then
      prefix=">"
      printf '%b%b  %s %-16s%b %s\n' \
        "$CYAN" "$BOLD" "$prefix" "${MENU_LABELS[$i]}" "$RESET" "${MENU_DESCS[$i]}"
    else
      printf '    %-16s %s\n' "${MENU_LABELS[$i]}" "${MENU_DESCS[$i]}"
    fi
  done
  footer
  # Erase anything left from a previously longer screen.
  printf '\033[J'
}

# menu_select TITLE [SUBTITLE [ALLOW_BACK [RESOURCE_SUMMARY]]]
# Blocking navigation loop. Returns:
#   0 — item selected (MENU_SELECTED holds the index)
#   1 — user pressed Back/Esc
#   2 — empty list
#   3 — user pressed Quit
menu_select() {
  local title="$1" subtitle="${2:-}" count
  MENU_ALLOW_BACK="${3:-1}"
  if [[ "$#" -ge 4 ]]; then
    RESOURCE_SUMMARY="$4"
  else
    docker_resource_summary
  fi
  count=${#MENU_LABELS[@]}
  [[ "$count" -gt 0 ]] || return 2
  if [[ "$MENU_SELECTED" -ge "$count" ]]; then MENU_SELECTED=$((count - 1)); fi
  if [[ "$MENU_SELECTED" -lt 0 ]];         then MENU_SELECTED=0; fi

  screen_clear
  hide_cursor
  while true; do
    draw_menu "$title" "$subtitle"
    read_key
    case "$KEY" in
      UP)
        if [[ "$MENU_SELECTED" -gt 0 ]]; then
          MENU_SELECTED=$((MENU_SELECTED - 1))
        else
          MENU_SELECTED=$((count - 1))
        fi
        ;;
      DOWN)
        if [[ "$MENU_SELECTED" -lt $((count - 1)) ]]; then
          MENU_SELECTED=$((MENU_SELECTED + 1))
        else
          MENU_SELECTED=0
        fi
        ;;
      ENTER) show_cursor; return 0 ;;
      ESC)
        if [[ "$MENU_ALLOW_BACK" -eq 1 ]]; then
          show_cursor
          return 1
        fi
        ;;
      QUIT) show_cursor; return 3 ;;
    esac
  done
}
