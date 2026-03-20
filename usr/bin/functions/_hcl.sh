#!/bin/bash

function hcl-get-variable() {
  jq -r --arg var "$2" '.variable.[$var][].default//empty' <<< "$(hcl2json "$1")"
}

function hcl-get-platforms() {
  hcl-get-variable "$1" "PLATFORMS"
}

function hcl-get-php-version() {
  hcl-get-variable "$1" "PHP_VERSION"
}

function hcl-find-target() {
  local current_dir="$1"
  local target_name="$2"
  local sibling hcl_file

  # Iterate over sibling directories
  for sibling in $(find "$current_dir/.." -maxdepth 1 -mindepth 1 -type d); do
    local hcl_file="$sibling/docker-bake.hcl"
    if [ -f "$hcl_file" ]; then
      if hcl-has-target "$hcl_file" "$target_name"; then
        echo "$hcl_file"
        return 0
      fi
    fi
  done

  echo ""
}

function hcl-has-target() {
  local target_exists json_output
  local hcl_file="$1"
  local target_name="$2"

  # Convert HCL to JSON
  local json_output=$(hcl2json < "$hcl_file")

  # Use jq to check if the specified target exists
  target_exists=$(jq -e --arg target "$target_name" '.target[$target] != null' <<< "$json_output")

  if [ "$target_exists" = "true" ]; then
    return 0
  else
    return 1
  fi
}