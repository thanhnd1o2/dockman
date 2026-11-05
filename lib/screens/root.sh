#!/usr/bin/env bash
# screens/root.sh — Top-level navigation and Docker engine startup screens.
# Depends on: core, docker/engine.sh, all other screens.

# start_colima_engine — UI wrapper to start Colima and wait for Docker.
start_colima_engine() {
  screen_clear
  header "Docker Engine" "Starting Colima"
  echo "Starting Colima..."; echo
  colima start || {
    echo
    printf '%b✗ Failed to start Colima.%b\n' "$RED" "$RESET"
    pause_screen
    return 1
  }
  wait_for_docker
}

# start_lima_engine INSTANCE — UI wrapper to start a Lima instance and wait for Docker.
start_lima_engine() {
  local instance="$1"
  screen_clear
  header "Docker Engine" "Starting Lima instance: $instance"
  echo "Starting Lima instance '$instance'..."; echo
  limactl start "$instance" || {
    echo
    printf '%b✗ Failed to start Lima instance "%s".%b\n' "$RED" "$instance" "$RESET"
    pause_screen
    return 1
  }
  wait_for_docker
}

# stop_docker_engine RUNTIME — confirm and stop the active Lima/Colima runtime.
stop_docker_engine() {
  local kind="${1%%:*}" instance="${1#*:}" rc
  screen_clear
  header "Docker Engine" "Stop $kind ($instance)"
  confirm "Stop Docker and its running containers?" || return 1
  echo
  case "$kind" in
    lima)   limactl stop "$instance"; rc=$? ;;
    colima) colima stop --profile "$instance"; rc=$? ;;
  esac
  if [[ "$rc" -ne 0 ]]; then
    printf '%b✗ Failed to stop Docker (%s).%b\n' "$RED" "$kind" "$RESET"
    pause_screen
    return 1
  fi
  printf '%b✓ Docker Engine stopped.%b\n' "$GREEN" "$RESET"
}

# main — top-level entry point.
main() {
  local rc action stop_target instance endpoint
  terminal_init
  check_docker_cli

  # Engine-not-running loop: offer Lima/Colima start or quit.
  while ! docker_is_running; do
    local lima_instance=""
    MENU_LABELS=(); MENU_DESCS=(); MENU_ACTIONS=()

    if command -v limactl >/dev/null 2>&1; then
      lima_instance="$(preferred_lima_instance 2>/dev/null || true)"
      if [[ -n "$lima_instance" ]]; then
        MENU_LABELS+=("Start Docker (Lima)")
        MENU_DESCS+=("Start Lima instance '$lima_instance' and wait for Docker Engine")
        MENU_ACTIONS+=("lima")
      fi
    fi

    if command -v colima >/dev/null 2>&1; then
      MENU_LABELS+=("Start Docker (Colima)")
      MENU_DESCS+=("Start Colima and wait for Docker Engine")
      MENU_ACTIONS+=("colima")
    fi

    MENU_LABELS+=("Quit")
    MENU_DESCS+=("Exit Docker Manager")
    MENU_ACTIONS+=("quit")
    MENU_SELECTED=0

    menu_select "Docker Manager" "○ Docker Engine stopped" 0 "Docker Engine is not running"; rc=$?
    [[ "$rc" -eq 3 ]] && { screen_clear; return; }
    action="${MENU_ACTIONS[$MENU_SELECTED]}"
    case "$action" in
      lima)   start_lima_engine "$lima_instance" || true ;;
      colima) start_colima_engine || true ;;
      quit)   screen_clear; return ;;
    esac
  done

  # Main navigation loop.
  while true; do
    stop_target=""
    if instance="$(detect_lima_instance 2>/dev/null)"; then
      endpoint="$(docker context inspect "$(docker context show 2>/dev/null)" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"
      case "$endpoint" in
        *"/.lima/$instance/"*) stop_target="lima:$instance" ;;
      esac
    fi
    if [[ -z "$stop_target" ]] && instance="$(detect_colima_profile 2>/dev/null)"; then
      stop_target="colima:$instance"
    fi
    MENU_LABELS=("Containers" "Images"           "Volumes"            "Networks"            "Ports"                "System"                    "Cleanup")
    MENU_DESCS=("Manage Docker containers" "Manage Docker images" "Manage Docker volumes" "Manage Docker networks" "Exposed port bindings" "Docker system information" "Clean unused Docker resources")
    MENU_ACTIONS=("containers" "images" "volumes" "networks" "ports" "system" "cleanup")
    if [[ -n "$stop_target" ]]; then
      MENU_LABELS+=("Stop Docker")
      MENU_DESCS+=("Stop the active ${stop_target%%:*} engine")
      MENU_ACTIONS+=("stop")
    fi
    MENU_SELECTED=0
    menu_select "Docker Manager" "$(docker context show 2>/dev/null || true)" 0; rc=$?
    if [[ "$rc" -eq 3 ]]; then
      screen_clear
      printf '%bBye!%b\n' "$GREEN" "$RESET"
      return
    fi
    action="${MENU_ACTIONS[$MENU_SELECTED]}"
    screen_clear
    case "$action" in
      containers) containers_screen; rc=$? ;;
      images)     images_screen;     rc=$? ;;
      volumes)    volumes_screen;    rc=$? ;;
      networks)   networks_screen;   rc=$? ;;
      ports)      ports_screen;      rc=$? ;;
      system)     system_screen;     rc=0  ;;
      cleanup)    cleanup_screen;    rc=$? ;;
      stop)       stop_docker_engine "$stop_target" && return; rc=0 ;;
    esac
    [[ "${rc:-0}" -eq 3 ]] && { screen_clear; return; }
  done
}
