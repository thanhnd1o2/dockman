#!/usr/bin/env bash
# screens/images.sh — Image list screen and detail submenu.
# Depends on: core, docker/images.sh.

# image_detail REF ID — per-image action submenu.
image_detail() {
  local ref="$1" id="$2" rc action
  while true; do
    MENU_LABELS=("Inspect" "Remove")
    MENU_DESCS=("Show image information" "Remove Docker image")
    MENU_SELECTED=0
    menu_select "$ref" "Docker image"; rc=$?
    [[ "$rc" -eq 1 ]] && return
    [[ "$rc" -eq 3 ]] && return 3
    action="${MENU_LABELS[$MENU_SELECTED]}"
    screen_clear
    case "$action" in
      Inspect) inspect_object image "$id" ;;
      Remove)
        if confirm "Remove image '$ref'?"; then
          docker image rm "$id" || true
          pause_screen
          return
        fi
        ;;
    esac
  done
}

# images_screen — main image list screen.
images_screen() {
  local rc i ref
  while true; do
    load_images
    MENU_LABELS=(); MENU_DESCS=()
    if [[ "${#IMAGE_IDS[@]}" -eq 0 ]]; then
      screen_clear; header "Images" "0 images"
      echo "No Docker images found."
      pause_screen
      return
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