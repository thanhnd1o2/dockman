#!/usr/bin/env bash
# docker/engine.sh — Docker engine detection, runtime start helpers, resource summary.
# Depends on: core only. No UI or confirmation logic.

RESOURCE_SUMMARY=""

# ---------- engine detection ----------

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

# ---------- Lima detection ----------

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
        *)      instance="" ;;
      esac
      ;;
  esac

  [[ -n "$instance" ]] || return 1
  limactl list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "$instance" || return 1
  printf '%s' "$instance"
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

# ---------- disk / resource summary ----------

docker_disk_summary() {
  local docker_root lima_instance line
  docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
  [[ -n "$docker_root" ]] || return 1

  if [[ -e "$docker_root" ]]; then
    # Native Linux: DockerRootDir is directly accessible on this host.
    line="$(df -Pk "$docker_root" 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  elif lima_instance="$(detect_lima_instance 2>/dev/null)"; then
    # Docker inside Lima VM: df must run inside the VM.
    line="$(limactl shell "$lima_instance" -- df -Pk "$docker_root" 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  elif command -v colima >/dev/null 2>&1; then
    # Docker inside Colima VM: df must run inside the VM.
    line="$(colima ssh -- df -Pk "$docker_root" 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
    # If docker_root not found in VM, fall back to VM root filesystem.
    [[ -n "$line" ]] || line="$(colima ssh -- df -Pk / 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  else
    # Docker Desktop or other remote context: not accessible on this host.
    # Fall back to host root filesystem as a rough indicator.
    line="$(df -Pk / 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
  fi

  [[ -n "$line" ]] || return 1
  awk 'BEGIN{OFS=""} {
    used=$1*1024; total=$2*1024;
    split("B KiB MiB GiB TiB",u," ");
    i=1; while(used>=1024 && i<5){used/=1024;i++}
    used_s=sprintf(used>=10?"%.0f %s":"%.1f %s",used,u[i]);
    i=1; while(total>=1024 && i<5){total/=1024;i++}
    total_s=sprintf(total>=10?"%.0f %s":"%.1f %s",total,u[i]);
    print used_s,"/",total_s," (",$3,")"
  }' <<< "$line"
}

# Populates the global RESOURCE_SUMMARY string.
docker_resource_summary() {
  local cpus memory containers running images disk
  cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo '?')"
  memory="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo '0')"
  containers="$(docker info --format '{{.Containers}}' 2>/dev/null || echo '?')"
  running="$(docker info --format '{{.ContainersRunning}}' 2>/dev/null || echo '?')"
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