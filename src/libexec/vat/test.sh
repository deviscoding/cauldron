#!/bin/zsh

function plugin-obj() {
  local in obj type name plugin

  type="$1"
  [[ ! -t 0 ]] && in=$(cat)
  [[ -z "$in" ]] && return 1

  # Set Context Based on
  name=$(jq -r '.key' <<< "$in")
  plugin=$(jq -r '.value' <<< "$in")
  if [[ "$type" == "git" || ("$type" == "core" && "${plugin:0:8}" == "https:") ]]; then
    context="$name-repo"
    file="$plugin"
    type="git"
  else
    context="$name-\${os}"
    file="$plugin/docker-bake.hcl"
  fi

  jq -c --arg cxt "$context" --arg typ "$type" --arg file "$file" '{ name: .key, plugin: .value, context: $cxt, type: $typ, file: $file  }' <<< "$in"
}

function dockerfile_extensions() {
  jq -r 'to_entries[]' <<< "$1"
  echo "FROM debian:stable-slim"
  echo "RUN \\"
  jq -r 'to_entries[] | "    --mount=type=bind,from=stage-\(.key),source=/,target=/src/\(.key) \\"' <<< "$1"
  echo "    set -e ; \\"
  echo "    echo \"### START: COPYING PLUGIN FILES ###\"; \\"
  echo "    mkdir -p /out &&"
  jq -r 'to_entries[] | "    cp -a /src/\(.key)/* /out/ && "' <<< "$1"
  echo "    echo \"### FINISH: COPYING PLUGIN FILES ###\""
}

input='{ "node": "https://github.com/node/node.git", "jq": "vat://jq", "mine": "mine" }'

# jq -c "to_entries[]" <<< "$input" | while read -r in; do 
#   read -r name plugin context type file < <(plugin-obj git <<< "$in" | jq -r '[.[]] | @tsv')
  
# done

dockerfile_extensions "$input"
