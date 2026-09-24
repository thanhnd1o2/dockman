#!/usr/bin/env bash
# screens/networks.sh — Network list screen and detail submenu.
# Depends on: core, docker/networks.sh.

# networks_screen — main network list and detail screen.
networks_screen() {
  local rc i name
  while true; do
    load_networks
    MENU_LABELS=(); MENU_DESCS=()
    for ((i=0; i<${#NETWORK_NAMES[@]}; i++)); do
      MENU_LABELS+=("${NETWORK_NAMES[$i]}")
      MENU_DESCS+=("Driver: ${NETWORK_DRIVERS[$i]}")
    done
    MENU_SELECTED=0
    menu_select "Networks" "${#NETWORK_NAMES[@]} networks"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    name="${NETWORK_NAMES[$MENU_SELECTED]}"

    # Detail submenu
    MENU_LABELS=("Inspect" "Remove")
    MENU_DESCS=("Show network information" "Remove Docker network")
    MENU_SELECTED=0
    menu_select "$name" "Docker network"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
    [[ "$rc" -eq 1 ]] && continue
    screen_clear
    if [[ "$MENU_SELECTED" -eq 0 ]]; then
      inspect_object network "$name"
    else
      # Built-in networks are protected at the docker layer.
      if network_is_builtin "$name"; then
        echo "Built-in network '$name' will not be removed."
        pause_screen
      else
        if confirm "Remove network '$name'?"; then
          docker network rm "$name" || true
          pause_screen
        fi
      fi
    fi
  done
}