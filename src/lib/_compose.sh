#!/usr/bin/env zsh

compose_pullAll() {
  local composeDir

  if [[ ! -t 0 ]]; then
   composeDir=$(cat)
   cd "$composeDir" || return 1
  fi

  docker compose -f "$argCompose" config --format yaml | yq '.services[].image' | xargs -I {} docker pull {}
}

compose_find() {
  local found targetDir
  if [[ ! -t 0 ]]; then
      targetDir=$(cat)
  else
      targetDir="$1"
  fi

  # Find the first matching file using standard find flags
  found=$(find "$targetDir" -type f \( \
  -name "docker-compose.yml" -o \
  -name "docker-compose.yaml" -o \
  -name "compose.yml" -o \
  -name "compose.yaml" \
  \) -print 2>/dev/null | head -1)

  # Output the result
  if [[ -n "$found" ]]; then
      found=$(cd "$(dirname "$found")" && echo "$(pwd)/$(basename "$found")")
      echo "$found"
      return 0
  fi

  return 1
}
