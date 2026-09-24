#!/usr/bin/env bash
# screens/containers.sh — Container list screen and detail submenu.
# Depends on: core, docker/containers.sh.

# view_logs NAME — streams live container logs; Q or Ctrl+C to quit.
view_logs() {
  local name="$1" log_pid="" key=""
  screen_clear
  header "$name" "Live logs"
  printf '%bPress Q or Ctrl+C to return.%b\n\n' "$DIM" "$RESET"

  docker logs -f --tail 200 "$name" &
  log_pid=$!
  trap 'kill '"$log_pid"' >/dev/null 2>&1 || true' INT

  while kill -0 "$log_pid" >/dev/null 2>&1; do
    if IFS= read -rsn1 -t 1 key; then
      case "$key" in q|Q) break ;; esac
    fi
  done

  kill "$log_pid" >/dev/null 2>&1 || true
  wait "$log_pid" 2>/dev/null || true
  trap - INT
}

# container_stats NAME — shows live docker stats; Ctrl+C to quit.
container_stats() {
  local name="$1"
  screen_clear
  header "$name" "Live stats"
  printf '%bPress Ctrl+C to return.%b\n\n' "$DIM" "$RESET"
  trap ':' INT
  docker stats "$name" || true
  trap - INT
}

# container_shell NAME — opens an interactive shell inside the container.
container_shell() {
  local name="$1" shell=""
  if docker exec "$name" sh -c 'command -v bash' >/dev/null 2>&1; then
    shell="/bin/bash"
  elif docker exec "$name" sh -c 'command -v sh' >/dev/null 2>&1; then
    shell="/bin/sh"
  else
    echo "No bash/sh found inside container."
    pause_screen
    return
  fi
  docker exec -it "$name" "$shell" || true
}

# container_status_colored STATUS
# Returns a color-coded single-line status string for display.
container_status_colored() {
  local status="$1"
  case "$status" in
    Up*)                       printf '%b● %s%b' "$GREEN"  "$status" "$RESET" ;;
    Paused*)                   printf '%b● %s%b' "$YELLOW" "$status" "$RESET" ;;
    Restarting*)               printf '%b● %s%b' "$YELLOW" "$status" "$RESET" ;;
    Exited*|Dead*|removing*)   printf '%b● %s%b' "$RED"    "$status" "$RESET" ;;
    Created*)                  printf '%b○ %s%b' "$DIM"    "$status" "$RESET" ;;
    *)                         printf '%b%s%b'   "$DIM"    "$status" "$RESET" ;;
  esac
}

# container_detail NAME — per-container action submenu.
container_detail() {
  local name="$1" action rc subtitle
  while true; do
    MENU_LABELS=(); MENU_DESCS=(); MENU_ACTIONS=()
    if container_running "$name"; then
      MENU_LABELS=("Logs"  "Inspect"                  "Shell"                  "Stats"               "Restart"            "Stop"             "Remove")
      MENU_DESCS=("View live container logs" "Show container information" "Open an interactive shell" "Live resource usage" "Restart container" "Stop container" "Remove container")
      MENU_ACTIONS=("logs" "inspect" "shell" "stats" "restart" "stop" "remove")
      subtitle="${GREEN}● Running${RESET}"
    else
      MENU_LABELS=("Start" "Logs"                   "Inspect"                  "Remove")
      MENU_DESCS=("Start container" "View existing container logs" "Show container information" "Remove container")
      MENU_ACTIONS=("start" "logs_once" "inspect" "remove")
      subtitle="${RED}● Stopped${RESET}"
    fi
    MENU_SELECTED=0
    container_resource_summary "$name" >/dev/null
    menu_select "$name" "$subtitle" 1 "$RESOURCE_SUMMARY"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    action="${MENU_ACTIONS[$MENU_SELECTED]}"
    screen_clear
    case "$action" in
      start)     docker start "$name"; pause_screen ;;
      stop)      docker stop "$name"; pause_screen ;;
      restart)   docker restart "$name"; pause_screen ;;
      logs)      view_logs "$name" ;;
      logs_once) header "$name" "Logs"; docker logs --tail 200 "$name" 2>&1 || true; pause_screen ;;
      inspect)   inspect_object container "$name" ;;
      shell)     container_shell "$name" ;;
      stats)     container_stats "$name" ;;
      remove)
        if confirm "Remove container '$name'?"; then
          docker rm -f "$name" || true
          pause_screen
          return
        fi
        ;;
    esac
  done
}

# containers_screen — main container list screen.
containers_screen() {
  local rc i
  while true; do
    load_containers
    MENU_LABELS=(); MENU_DESCS=()
    if [[ "${#CONTAINER_NAMES[@]}" -eq 0 ]]; then
      screen_clear; header "Containers" "0 containers"
      echo "No Docker containers found."
      pause_screen
      return
    fi
    for ((i=0; i<${#CONTAINER_NAMES[@]}; i++)); do
      MENU_LABELS+=("${CONTAINER_NAMES[$i]}")
      local colored_status
      colored_status="$(container_status_colored "${CONTAINER_STATUS[$i]}")"
      MENU_DESCS+=("${colored_status}  •  ${CONTAINER_IMAGES[$i]}")
    done
    MENU_SELECTED=0
    menu_select "Containers" "${#CONTAINER_NAMES[@]} containers"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    container_detail "${CONTAINER_NAMES[$MENU_SELECTED]}"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
  done
}