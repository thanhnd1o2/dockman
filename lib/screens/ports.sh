#!/usr/bin/env bash
# screens/ports.sh — Exposed port bindings overview screen.
# Depends on: core, docker/ports.sh, screens/containers.sh.

# ports_screen — lists every port binding across all running containers.
# Selecting a binding navigates to that container's detail screen.
ports_screen() {
  local rc i
  while true; do
    load_port_bindings

    if [[ "${#PORT_NAMES[@]}" -eq 0 ]]; then
      screen_clear
      header "Ports" "No running containers"
      echo "No running containers with exposed ports."
      pause_screen
      return
    fi

    # Count distinct containers for the subtitle.
    local seen_names total_bindings distinct=0 prev=""
    total_bindings=${#PORT_NAMES[@]}
    # Simple distinct count: sort names and count unique.
    local sorted_names
    sorted_names="$(printf '%s\n' "${PORT_NAMES[@]}" | sort -u)"
    while IFS= read -r _name; do
      [[ -n "$_name" ]] && distinct=$((distinct + 1))
    done <<< "$sorted_names"

    MENU_LABELS=(); MENU_DESCS=()
    for ((i=0; i<total_bindings; i++)); do
      local binding="${PORT_BINDINGS[$i]}"
      local cname="${PORT_NAMES[$i]}"
      if [[ "$binding" == "(none)" ]]; then
        MENU_LABELS+=("${DIM}${cname}${RESET}")
        MENU_DESCS+=("${DIM}no ports exposed${RESET}")
      else
        # Highlight the host-side port in cyan for quick scanning.
        local host_part container_part
        # binding format: "0.0.0.0:8080->80/tcp" or ":::8080->80/tcp"
        host_part="${binding%%->*}"
        container_part="${binding#*->}"
        MENU_LABELS+=("${CYAN}${host_part}${RESET}")
        MENU_DESCS+=("${DIM}→ ${container_part}${RESET}  ${cname}")
      fi
    done

    MENU_SELECTED=0
    menu_select "Ports" "${distinct} containers  •  ${total_bindings} bindings"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3

    # Navigate to the container detail for the selected binding.
    local selected_container="${PORT_NAMES[$MENU_SELECTED]}"
    screen_clear
    container_detail "$selected_container"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
  done
}