#!/usr/bin/env bash
# Docker Manager - dependency-free interactive TUI for macOS/Linux.
# Compatible with macOS Bash 3.2.
set -u

# ---------- terminal / colors ----------
if [[ -t 1 ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
else
  RESET=''; BOLD=''; DIM=''; CYAN=''; GREEN=''; YELLOW=''; RED=''
fi

MENU_SELECTED=0
KEY=""
SCREEN_FIRST_DRAW=1

cleanup_terminal() {
  printf '\033[?25h%b' "$RESET"
}
trap cleanup_terminal EXIT
trap 'cleanup_terminal; exit 130' INT TERM

screen_clear() {
  printf '\033[2J\033[H'
}

cursor_home() {
  printf '\033[H'
}

hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

pause_screen() {
  echo
  read -r -p "Press Enter to return..." _
}

detect_lima_instance() {
  local context endpoint instance
  command -v limactl >/dev/null 2>&1 || return 1

  context="$(docker context show 2>/dev/null || true)"
  endpoint="$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"

  # Typical Lima socket: unix:///Users/me/.lima/<instance>/sock/docker.sock
  case "$endpoint" in
    *"/.lima/"*)
      instance="${endpoint#*/.lima/}"
      instance="${instance%%/*}"
      ;;
    *)
      # Common context convention: lima-docker -> docker.
      case "$context" in
        lima-*) instance="${context#lima-}" ;;
        *) instance="" ;;
      esac
      ;;
  esac

  [[ -n "$instance" ]] || return 1
  limactl list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "$instance" || return 1
  printf '%s' "$instance"
}

docker_disk_summary() {
  local docker_root lima_instance line
  docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
  [[ -n "$docker_root" ]] || return 1

  # Docker daemon inside Lima: df must run inside that VM, not on macOS.
  if lima_instance="$(detect_lima_instance 2>/dev/null)"; then
    line="$(limactl shell "$lima_instance" -- df -Pk "$docker_root" 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  # Native Linux / local daemon: DockerRootDir is visible on this host.
  elif [[ -e "$docker_root" ]]; then
    line="$(df -Pk "$docker_root" 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  else
    # Docker Desktop / remote contexts do not expose daemon filesystem to this shell.
    return 1
  fi

  [[ -n "$line" ]] || return 1
  awk 'BEGIN{OFS=""} {
    used=$1*1024; total=$2*1024;
    split("B KiB MiB GiB TiB",u," ");
    i=1; while(used>=1024 && i<5){used/=1024;i++} used_s=sprintf(used>=10?"%.0f %s":"%.1f %s",used,u[i]);
    i=1; while(total>=1024 && i<5){total/=1024;i++} total_s=sprintf(total>=10?"%.0f %s":"%.1f %s",total,u[i]);
    print used_s,"/",total_s," (",$3,")"
  }' <<< "$line"
}

docker_resource_summary() {
  local cpus memory containers running images disk
  cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo '?')"
  memory="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo '0')"
  containers="$(docker info --format '{{.Containers}}' 2>/dev/null || echo '?')"
  running="$(docker info --format '{{.ContainersRunning}}' 2>/dev/null || echo '?')"
  # Match the Images screen: count only images shown by `docker image ls`.
  # `docker info .Images` may include hidden/intermediate image objects.
  images="$(docker image ls --format '{{.ID}}' 2>/dev/null | awk 'NF {count++} END {print count+0}')"

  if [[ "$memory" =~ ^[0-9]+$ ]] && [[ "$memory" -gt 0 ]]; then
    memory="$(awk -v b="$memory" 'BEGIN {printf "%.1f GiB", b/1073741824}')"
  else
    memory="?"
  fi

  RESOURCE_SUMMARY="CPU ${cpus}  •  RAM ${memory}  •  Containers ${running}/${containers}  •  Images ${images}"
  if disk="$(docker_disk_summary 2>/dev/null)"; then
    RESOURCE_SUMMARY="${RESOURCE_SUMMARY}  •  Disk ${disk}"
  fi
}

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

footer() {
  if [[ "${MENU_ALLOW_BACK:-1}" -eq 1 ]]; then
    printf '\n%b  ↑↓: Navigate  •  →/Enter: Select  •  ←/Esc: Back  •  Q: Quit%b\n' "$DIM" "$RESET"
  else
    printf '\n%b  ↑↓: Navigate  •  →/Enter: Select  •  Q: Quit%b\n' "$DIM" "$RESET"
  fi
}

die() {
  printf '%bError:%b %s\n' "$RED$BOLD" "$RESET" "$1" >&2
  exit 1
}

check_docker_cli() {
  command -v docker >/dev/null 2>&1 || die "Docker CLI is not installed."
}

docker_is_running() {
  docker info >/dev/null 2>&1
}

wait_for_docker() {
  local i
  echo
  printf 'Waiting for Docker Engine'
  for ((i=0; i<60; i++)); do
    if docker_is_running; then
      echo; echo
      printf '%b✓ Docker Engine is ready.%b\n' "$GREEN$BOLD" "$RESET"
      sleep 1
      return 0
    fi
    printf '.'
    sleep 1
  done
  echo; echo
  printf '%b✗ Docker Engine did not become ready within 60 seconds.%b\n' "$RED" "$RESET"
  pause_screen
  return 1
}

preferred_lima_instance() {
  local instance
  instance="$(detect_lima_instance 2>/dev/null || true)"
  if [[ -n "$instance" ]]; then printf '%s' "$instance"; return 0; fi
  if command -v limactl >/dev/null 2>&1 && limactl list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx docker; then
    printf '%s' docker; return 0
  fi
  instance="$(limactl list 2>/dev/null | awk 'NR > 1 && $1 != "" {print $1; exit}')"
  [[ -n "$instance" ]] && { printf '%s' "$instance"; return 0; }
  return 1
}

start_colima_engine() {
  screen_clear
  header "Docker Engine" "Starting Colima"
  echo "Starting Colima..."; echo
  colima start || { echo; printf '%b✗ Failed to start Colima.%b\n' "$RED" "$RESET"; pause_screen; return 1; }
  wait_for_docker
}

start_lima_engine() {
  local instance="$1"
  screen_clear
  header "Docker Engine" "Starting Lima instance: $instance"
  echo "Starting Lima instance '$instance'..."; echo
  limactl start "$instance" || { echo; printf '%b✗ Failed to start Lima instance "%s".%b\n' "$RED" "$instance" "$RESET"; pause_screen; return 1; }
  wait_for_docker
}

# Read one optional byte with a 0.1s terminal-level timeout.
# `stty time` is measured in tenths of a second, so this works with
# macOS Bash 3.2 without relying on unsupported fractional `read -t`.
read_escape_byte() {
  local saved byte
  saved="$(stty -g 2>/dev/null)" || return 1
  stty -echo -icanon min 0 time 1 2>/dev/null || return 1
  byte="$(dd bs=1 count=1 2>/dev/null)"
  stty "$saved" 2>/dev/null || true
  [[ -n "$byte" ]] || return 1
  printf '%s' "$byte"
}

# Reads arrows while keeping a standalone Esc responsive.
read_key() {
  local k="" k2="" k3=""
  IFS= read -rsn1 k || true
  case "$k" in
    $'\x1b')
      k2="$(read_escape_byte || true)"
      if [[ "$k2" == "[" || "$k2" == "O" ]]; then
        k3="$(read_escape_byte || true)"
        case "$k3" in
          A) KEY="UP" ;;
          B) KEY="DOWN" ;;
          C) KEY="ENTER" ;;  # Right arrow = open/select
          D) KEY="ESC" ;;    # Left arrow = back
          *) KEY="ESC" ;;
        esac
      else
        KEY="ESC"
      fi
      ;;
    "") KEY="ENTER" ;;
    j|J) KEY="DOWN" ;;
    k|K) KEY="UP" ;;
    q|Q) KEY="QUIT" ;;
    *) KEY="$k" ;;
  esac
}

# MENU_LABELS and MENU_DESCS must be populated by caller.
draw_menu() {
  local title="$1" subtitle="${2:-}" i prefix
  cursor_home
  header "$title" "$subtitle"
  for ((i=0; i<${#MENU_LABELS[@]}; i++)); do
    if [[ "$i" -eq "$MENU_SELECTED" ]]; then
      prefix=">"
      printf '%b%b  %s %-16s%b %s\n' "$CYAN" "$BOLD" "$prefix" "${MENU_LABELS[$i]}" "$RESET" "${MENU_DESCS[$i]}"
    else
      printf '    %-16s %s\n' "${MENU_LABELS[$i]}" "${MENU_DESCS[$i]}"
    fi
  done
  footer
  # Erase anything left from a previously longer screen.
  printf '\033[J'
}

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
  if [[ "$MENU_SELECTED" -lt 0 ]]; then MENU_SELECTED=0; fi

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

confirm() {
  local prompt="$1" answer=""
  read -r -p "$prompt [y/N]: " answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ---------- Docker helpers ----------
container_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" == "true" ]]
}

container_resource_summary() {
  local name="$1" info image state health ports stats cpu mem

  info="$(docker inspect -f '{{.Config.Image}}\t{{.State.Status}}\t{{if .State.Health}}{{.State.Health.Status}}{{else}}-{{end}}' "$name" 2>/dev/null || true)"
  IFS=$'\t' read -r image state health <<< "$info"
  [[ -n "$image" ]] || image="?"
  [[ -n "$state" ]] || state="?"

  ports="$(docker port "$name" 2>/dev/null | awk '{print $3}' | paste -sd ',' - 2>/dev/null || true)"
  [[ -n "$ports" ]] || ports="None"

  RESOURCE_SUMMARY="State ${state}  •  Image ${image}"
  if [[ -n "$health" && "$health" != "-" ]]; then
    RESOURCE_SUMMARY="${RESOURCE_SUMMARY}  •  Health ${health}"
  fi

  if [[ "$state" == "running" ]]; then
    stats="$(docker stats --no-stream --format '{{.CPUPerc}}\t{{.MemUsage}}' "$name" 2>/dev/null || true)"
    IFS=$'\t' read -r cpu mem <<< "$stats"
    [[ -n "$cpu" ]] && RESOURCE_SUMMARY="${RESOURCE_SUMMARY}  •  CPU ${cpu}"
    [[ -n "$mem" ]] && RESOURCE_SUMMARY="${RESOURCE_SUMMARY}  •  Memory ${mem}"
  fi

  RESOURCE_SUMMARY="${RESOURCE_SUMMARY}  •  Ports ${ports}"
  printf '%s' "$RESOURCE_SUMMARY"
}

container_shell() {
  local name="$1" shell=""
  if docker exec "$name" sh -c 'command -v bash' >/dev/null 2>&1; then shell="/bin/bash"
  elif docker exec "$name" sh -c 'command -v sh' >/dev/null 2>&1; then shell="/bin/sh"
  else
    echo "No bash/sh found inside container."
    pause_screen
    return
  fi
  docker exec -it "$name" "$shell" || true
}

view_logs() {
  local name="$1" log_pid="" key=""
  screen_clear
  header "$name" "Live logs"
  printf '%bPress Q or Ctrl+C to return.%b\n\n' "$DIM" "$RESET"

  # Follow logs in background so Q can stop them.
  docker logs -f --tail 200 "$name" &
  log_pid=$!

  trap 'kill '"$log_pid"' >/dev/null 2>&1 || true' INT

  while kill -0 "$log_pid" >/dev/null 2>&1; do
    # Integer timeout: compatible with Bash 3.2.
    if IFS= read -rsn1 -t 1 key; then
      case "$key" in q|Q) break ;; esac
    fi
  done

  kill "$log_pid" >/dev/null 2>&1 || true
  wait "$log_pid" 2>/dev/null || true
  trap - INT
}

container_stats() {
  local name="$1"
  screen_clear
  header "$name" "Live stats"
  printf '%bPress Ctrl+C to return.%b\n\n' "$DIM" "$RESET"
  trap ':' INT
  docker stats "$name" || true
  trap - INT
}

inspect_object() {
  local kind="$1" id="$2"
  screen_clear
  header "$id" "Docker $kind inspect"
  docker "$kind" inspect "$id" || true
  pause_screen
}

# ---------- Containers ----------
load_containers() {
  CONTAINER_IDS=(); CONTAINER_NAMES=(); CONTAINER_STATUS=(); CONTAINER_IMAGES=()
  while IFS=$'\t' read -r id name status image; do
    [[ -n "$id" ]] || continue
    CONTAINER_IDS[${#CONTAINER_IDS[@]}]="$id"
    CONTAINER_NAMES[${#CONTAINER_NAMES[@]}]="$name"
    CONTAINER_STATUS[${#CONTAINER_STATUS[@]}]="$status"
    CONTAINER_IMAGES[${#CONTAINER_IMAGES[@]}]="$image"
  done < <(docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}')
}

container_detail() {
  local name="$1" action rc
  while true; do
    MENU_LABELS=(); MENU_DESCS=(); MENU_ACTIONS=()
    if container_running "$name"; then
      MENU_LABELS+=("Logs" "Inspect" "Shell" "Stats" "Restart" "Stop" "Remove")
      MENU_DESCS+=("View live container logs" "Show container information" "Open an interactive shell" "Live resource usage" "Restart container" "Stop container" "Remove container")
      MENU_ACTIONS+=("logs" "inspect" "shell" "stats" "restart" "stop" "remove")
      subtitle="● Running"
    else
      MENU_LABELS+=("Start" "Logs" "Inspect" "Remove")
      MENU_DESCS+=("Start container" "View existing container logs" "Show container information" "Remove container")
      MENU_ACTIONS+=("start" "logs_once" "inspect" "remove")
      subtitle="○ Stopped"
    fi
    MENU_SELECTED=0
    container_resource_summary "$name" >/dev/null
    menu_select "$name" "$subtitle" 1 "$RESOURCE_SUMMARY"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    action="${MENU_ACTIONS[$MENU_SELECTED]}"
    screen_clear
    case "$action" in
      start) docker start "$name"; pause_screen ;;
      stop) docker stop "$name"; pause_screen ;;
      restart) docker restart "$name"; pause_screen ;;
      logs) view_logs "$name" ;;
      logs_once) header "$name" "Logs"; docker logs --tail 200 "$name" 2>&1 || true; pause_screen ;;
      inspect) inspect_object container "$name" ;;
      shell) container_shell "$name" ;;
      stats) container_stats "$name" ;;
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
      MENU_DESCS+=("${CONTAINER_STATUS[$i]}  •  ${CONTAINER_IMAGES[$i]}")
    done
    MENU_SELECTED=0
    menu_select "Containers" "${#CONTAINER_NAMES[@]} containers"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    container_detail "${CONTAINER_NAMES[$MENU_SELECTED]}"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
  done
}

# ---------- Images ----------
load_images() {
  IMAGE_IDS=(); IMAGE_REPOS=(); IMAGE_TAGS=(); IMAGE_SIZES=()
  while IFS=$'\t' read -r id repo tag size; do
    [[ -n "$id" ]] || continue
    IMAGE_IDS[${#IMAGE_IDS[@]}]="$id"
    IMAGE_REPOS[${#IMAGE_REPOS[@]}]="$repo"
    IMAGE_TAGS[${#IMAGE_TAGS[@]}]="$tag"
    IMAGE_SIZES[${#IMAGE_SIZES[@]}]="$size"
  done < <(docker image ls --format '{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}')
}

image_detail() {
  local ref="$1" id="$2" rc action
  while true; do
    MENU_LABELS=("Inspect" "Remove")
    MENU_DESCS=("Show image information" "Remove Docker image")
    MENU_ACTIONS=("inspect" "remove")
    MENU_SELECTED=0
    menu_select "$ref" "Docker image"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    action="${MENU_ACTIONS[$MENU_SELECTED]}"
    screen_clear
    case "$action" in
      inspect) inspect_object image "$id" ;;
      remove)
        if confirm "Remove image '$ref'?"; then
          docker image rm "$id" || true
          pause_screen
          return
        fi
        ;;
    esac
  done
}

images_screen() {
  local rc i ref
  while true; do
    load_images
    MENU_LABELS=(); MENU_DESCS=()
    if [[ "${#IMAGE_IDS[@]}" -eq 0 ]]; then
      screen_clear; header "Images" "0 images"; echo "No Docker images found."; pause_screen; return
    fi
    for ((i=0; i<${#IMAGE_IDS[@]}; i++)); do
      ref="${IMAGE_REPOS[$i]}:${IMAGE_TAGS[$i]}"
      MENU_LABELS+=("$ref")
      MENU_DESCS+=("${IMAGE_SIZES[$i]}  •  ${IMAGE_IDS[$i]}")
    done
    MENU_SELECTED=0
    menu_select "Docker Images" "${#IMAGE_IDS[@]} images"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    ref="${IMAGE_REPOS[$MENU_SELECTED]}:${IMAGE_TAGS[$MENU_SELECTED]}"
    image_detail "$ref" "${IMAGE_IDS[$MENU_SELECTED]}"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
  done
}

# ---------- Volumes ----------
volumes_screen() {
  local rc i name
  while true; do
    VOLUMES=()
    while IFS= read -r name; do [[ -n "$name" ]] && VOLUMES[${#VOLUMES[@]}]="$name"; done < <(docker volume ls --format '{{.Name}}')
    if [[ "${#VOLUMES[@]}" -eq 0 ]]; then
      screen_clear; header "Volumes" "0 volumes"; echo "No Docker volumes found."; pause_screen; return
    fi
    MENU_LABELS=(); MENU_DESCS=()
    for ((i=0; i<${#VOLUMES[@]}; i++)); do MENU_LABELS+=("${VOLUMES[$i]}"); MENU_DESCS+=("Docker volume"); done
    MENU_SELECTED=0
    menu_select "Volumes" "${#VOLUMES[@]} volumes"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    name="${VOLUMES[$MENU_SELECTED]}"
    MENU_LABELS=("Inspect" "Remove"); MENU_DESCS=("Show volume information" "Remove Docker volume")
    MENU_SELECTED=0
    menu_select "$name" "Docker volume"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
    [[ "$rc" -eq 1 ]] && continue
    screen_clear
    if [[ "$MENU_SELECTED" -eq 0 ]]; then
      inspect_object volume "$name"
    else
      if confirm "Remove volume '$name'?"; then docker volume rm "$name" || true; pause_screen; fi
    fi
  done
}

# ---------- Networks ----------
networks_screen() {
  local rc i name driver
  while true; do
    NETWORK_NAMES=(); NETWORK_DRIVERS=()
    while IFS=$'\t' read -r name driver; do
      [[ -n "$name" ]] || continue
      NETWORK_NAMES[${#NETWORK_NAMES[@]}]="$name"; NETWORK_DRIVERS[${#NETWORK_DRIVERS[@]}]="$driver"
    done < <(docker network ls --format '{{.Name}}\t{{.Driver}}')
    MENU_LABELS=(); MENU_DESCS=()
    for ((i=0; i<${#NETWORK_NAMES[@]}; i++)); do
      MENU_LABELS+=("${NETWORK_NAMES[$i]}"); MENU_DESCS+=("Driver: ${NETWORK_DRIVERS[$i]}")
    done
    MENU_SELECTED=0
    menu_select "Networks" "${#NETWORK_NAMES[@]} networks"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    name="${NETWORK_NAMES[$MENU_SELECTED]}"
    MENU_LABELS=("Inspect" "Remove"); MENU_DESCS=("Show network information" "Remove Docker network")
    MENU_SELECTED=0
    menu_select "$name" "Docker network"; rc=$?
    [[ "$rc" -eq 3 ]] && return 3
    [[ "$rc" -eq 1 ]] && continue
    screen_clear
    if [[ "$MENU_SELECTED" -eq 0 ]]; then
      inspect_object network "$name"
    else
      case "$name" in
        bridge|host|none) echo "Built-in network '$name' will not be removed."; pause_screen ;;
        *) if confirm "Remove network '$name'?"; then docker network rm "$name" || true; pause_screen; fi ;;
      esac
    fi
  done
}

# ---------- System / Cleanup ----------
system_screen() {
  screen_clear
  header "Docker System" "$(docker context show 2>/dev/null || true)"
  docker version 2>/dev/null || true
  echo
  docker system df 2>/dev/null || true
  echo
  docker info --format 'Containers: {{.Containers}}  Running: {{.ContainersRunning}}  Images: {{.Images}}' 2>/dev/null || true
  pause_screen
}

cleanup_screen() {
  local rc action
  while true; do
    MENU_LABELS=("Containers" "Images" "Volumes" "Networks" "System prune")
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
      images) confirm "Prune dangling images?" && docker image prune -f ;;
      volumes) confirm "Prune unused volumes?" && docker volume prune -f ;;
      networks) confirm "Prune unused networks?" && docker network prune -f ;;
      system) confirm "Run docker system prune?" && docker system prune -f ;;
    esac
    pause_screen
  done
}

# ---------- Main ----------
main() {
  local rc action
  check_docker_cli

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
      lima) start_lima_engine "$lima_instance" || true ;;
      colima) start_colima_engine || true ;;
      quit) screen_clear; return ;;
    esac
  done

  while true; do
    MENU_LABELS=("Containers" "Images" "Volumes" "Networks" "System" "Cleanup")
    MENU_DESCS=("Manage Docker containers" "Manage Docker images" "Manage Docker volumes" "Manage Docker networks" "Docker system information" "Clean unused Docker resources")
    MENU_ACTIONS=("containers" "images" "volumes" "networks" "system" "cleanup")
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
      images) images_screen; rc=$? ;;
      volumes) volumes_screen; rc=$? ;;
      networks) networks_screen; rc=$? ;;
      system) system_screen; rc=0 ;;
      cleanup) cleanup_screen; rc=$? ;;
    esac
    [[ "${rc:-0}" -eq 3 ]] && { screen_clear; return; }
  done
}

main "$@"
