#!/usr/bin/env bash
# docker/networks.sh — Pure Docker network data operations.
# Depends on: core only. No UI or confirmation logic.

# Built-in Docker networks protected from removal.
DOCKER_BUILTIN_NETWORKS="bridge host none"

# Populates NETWORK_NAMES and NETWORK_DRIVERS arrays.
load_networks() {
  NETWORK_NAMES=(); NETWORK_DRIVERS=()
  local name driver
  while IFS=$'\t' read -r name driver; do
    [[ -n "$name" ]] || continue
    NETWORK_NAMES[${#NETWORK_NAMES[@]}]="$name"
    NETWORK_DRIVERS[${#NETWORK_DRIVERS[@]}]="$driver"
  done < <(docker network ls --format '{{.Name}}\t{{.Driver}}')
}

# network_is_builtin NAME — returns 0 if the network is a built-in and must not be removed.
network_is_builtin() {
  local name="$1" n
  for n in $DOCKER_BUILTIN_NETWORKS; do
    [[ "$name" == "$n" ]] && return 0
  done
  return 1
}