#!/usr/bin/env bash
# docker/containers.sh — Pure Docker container data operations.
# Depends on: core only. No UI or confirmation logic.

# Populates CONTAINER_IDS, CONTAINER_NAMES, CONTAINER_STATUS, CONTAINER_IMAGES.
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

# container_running NAME — returns 0 if the container is currently running.
container_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" == "true" ]]
}

# container_resource_summary NAME
# Populates RESOURCE_SUMMARY with state, image, health, cpu, mem, and ports.
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