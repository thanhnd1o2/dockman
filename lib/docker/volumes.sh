#!/usr/bin/env bash
# docker/volumes.sh — Pure Docker volume data operations.
# Depends on: core only. No UI or confirmation logic.

# Populates VOLUMES array with volume names.
load_volumes() {
  VOLUMES=()
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && VOLUMES[${#VOLUMES[@]}]="$name"
  done < <(docker volume ls --format '{{.Name}}')
}