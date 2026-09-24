#!/usr/bin/env bash
# screens/volumes.sh — Volume list screen and detail submenu.
# Depends on: core, docker/volumes.sh.

# volumes_screen — main volume list and detail screen.
volumes_screen() {
  local rc i name
  while true; do
    load_volumes
    if [[ "${#VOLUMES[@]}" -eq 0 ]]; then
      screen_clear; header "Volumes" "0 volumes"
      echo "No Docker volumes found."
      pause_screen
      return
    fi
    MENU_LABELS=(); MENU_DESCS=()
    for ((i=0; i<${#VOLUMES[@]}; i++)); do
      MENU_LABELS+=("${VOLUMES[$i]}")
      MENU_DESCS+=("Docker volume")
    done
    MENU_SELECTED=0
    menu_select "Volumes" "${#VOLUMES[@]} volumes"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    name="${VOLUMES[$MENU_SELECTED]}"

    # Detail submenu
    MENU_LABELS=("Inspect" "Remove")
    MENU_DESCS=("Show volume information" "Remove Docker volume")
    MENU_SELECTED=0
    menu_select "$name" "Docker volume"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
    [[ "$rc" -eq 1 ]] && continue
    screen_clear
    if [[ "$MENU_SELECTED" -eq 0 ]]; then
      inspect_object volume "$name"
    else
      if confirm "Remove volume '$name'?"; then
        docker volume rm "$name" || true
        pause_screen
      fi
    fi
  done
}