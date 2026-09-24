#!/usr/bin/env bash
# docker/images.sh — Pure Docker image data operations.
# Depends on: core only. No UI or confirmation logic.

# Populates IMAGE_IDS, IMAGE_REPOS, IMAGE_TAGS, IMAGE_SIZES.
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