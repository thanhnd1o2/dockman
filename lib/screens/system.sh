#!/usr/bin/env bash
# screens/system.sh — Docker system information screen.
# Depends on: core.

# system_screen — displays docker version, disk usage, and container counts.
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