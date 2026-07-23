#!/bin/bash

function env::has() {
  local envFile key

  local key="$1"
  if [[ ! -t 0 ]]; then
    envFile=$(cat)
  fi

  if [[ -f "$envFile" ]]; then
    grep -q "^${key}=" "$envFile" 2>/dev/null
  else
    return 1
  fi
}

function env::bulldoze() {
  local key val file req

  file="$1"
  key="$2"
  val="$3"
  req="# Required ${key}=${val}"
  # Check if environment var Exists
  if grep -q "^${key}=" "$file"; then
    # Comment Out Existing line
    sed -i "s|^${key}=|# ${val}=|" "$file"
    # (Uses 'a' command in sed to append after the line we just commented out)
    sed -i "/^# ${key}=/a ${req}\n${key}=${val}" "$file"
  else
    # Append if not present
    env::append "$file" "$2" "$3"
  fi
}

function env::append() {
  local key val file req

  if [[ ! -t 0 ]]; then
    file=$(cat)
  fi

  key="$1"
  val="$2"
  req="# Required ${key}=${val}"

  if ! grep -q "^${key}=" "$file"; then
    echo "$req" >> "$file"
    echo "${key}=${val}" >> "$file"
  fi
}
