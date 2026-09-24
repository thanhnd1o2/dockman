#!/usr/bin/env bash
# screens/cleanup.sh — Prune / cleanup screen.
# Depends on: core. All destructive actions require confirmation.

# cleanup_screen — menu-driven Docker resource pruning.
cleanup_screen() {
  local rc action
  while true; do
    MENU_LABELS=("Containers" "Images"             "Volumes"              "Networks"              "System prune")
    MENU_DESCS=("Remove stopped containers" "Remove dangling images" "Remove unused volumes" "Remove unused networks" "Remove all unused Docker data")
    MENU_ACTIONS=("containers" "images" "volumes" "networks" "system")
    MENU_SELECTED=0
    menu_select "Cleanup" "Destructive actions require confirmation"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    action="${MENU_ACTIONS[$MENU_SELECTED]}"
    screen_clear
    case "$action" in
      containers) confirm "Prune stopped containers?" && docker container prune -f ;;
      images)     confirm "Prune dangling images?"     && docker image prune -f     ;;
      volumes)    confirm "Prune unused volumes?"      && docker volume prune -f    ;;
      networks)   confirm "Prune unused networks?"     && docker network prune -f   ;;
      system)     confirm "Run docker system prune?"   && docker system prune -f    ;;
    esac
    pause_screen
  done
}