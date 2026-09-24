#!/usr/bin/env bash
# docker/ports.sh — Port binding data operations.
# Depends on: core only. No UI or confirmation logic.

# load_port_bindings
# Populates PORT_NAMES (container name) and PORT_BINDINGS (binding string)
# for every port binding across all running containers.
# Containers with no exposed ports get a single entry with binding "(none)".
load_port_bindings() {
  PORT_NAMES=(); PORT_BINDINGS=()
  local name ports binding
  while IFS=$'\t' read -r name ports; do
    [[ -n "$name" ]] || continue
    if [[ -z "$ports" ]]; then
      PORT_NAMES+=("$name")
      PORT_BINDINGS+=("(none)")
      continue
    fi
    # Ports field: "0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp"
    # Split on ", " into individual bindings.
    local old_ifs="$IFS"
    IFS=','
    local parts
    read -ra parts <<< "$ports"
    IFS="$old_ifs"
    for binding in "${parts[@]}"; do
      # Trim leading/trailing whitespace.
      binding="${binding#" "}"; binding="${binding%" "}"
      [[ -n "$binding" ]] || continue
      PORT_NAMES+=("$name")
      PORT_BINDINGS+=("$binding")
    done
  done < <(docker ps --format '{{.Names}}\t{{.Ports}}')
}