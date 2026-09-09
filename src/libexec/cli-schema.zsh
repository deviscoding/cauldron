#!/usr/bin/env zsh

# @file cli-schema.sh
# @brief Parses the docker compose documentation and generates a schema for the CLI command options.
#
# @author  AMJones <am@jonesiscoding>
# @version ##VERSION##
# @revision
# @built

selfRepo="deviscoding/vat"
selfApp="vat"
selfName="cli-schema.zsh"
selfDir=$(cd -- "$(dirname -- "$0")" && pwd -P)
selfLib=$( cd "${selfDir/\/libexec//lib}" && pwd -P)
cmdBlock=("bridge" "commit" "convert" "create" "export" "push" "rm" "scale" "wait" "watch")

source "$selfLib/_colors.sh"

function docs-get-hash() {
  local cwd=$(pwd)
  cd "$repoDir" && git rev-parse HEAD 2>/dev/null && cd "$cwd"
}

function docs-repo-clone() {
  local cwd=$(pwd)
  # Clone the docker/compose repo with sparse checkout and specific branch
  if ! git clone --depth 1 --branch "v${composeVer}" --sparse \
    https://github.com/docker/compose.git "$repoDir" >/dev/null 2>&1; then
    return $?
  fi

  cd "$repoDir" || return 1
  git sparse-checkout set docs/reference >/dev/null 2>&1
  retval=$?
  cd "$cwd" && return "$retval"
}

function docs-repo-pull() {
  local prevHash newHash cwd

  cwd=$(pwd)
  cd "$repoDir" || exit 1

  # Disable interactive prompts
  export GIT_TERMINAL_PROMPT=0

  # Force fully wipe any accidental workspace modifications
  # Fetch updates for the tag, checkout tag, set sparse.
  git clean -dxf >/dev/null 2>&1 &&
    git reset --hard HEAD >/dev/null 2>&1 &&
    git clean -dxf >/dev/null 2>&1 &&
    git fetch --depth 1 origin "v$composeVer" >/dev/null 2>&1 &&
    git sparse-checkout set docs/reference >/dev/null 2>&1 

  retval=$?
  cd $cwd
  return $retval
}

# Check if docker-compose is available and get its version
if ! command -v docker-compose &>/dev/null; then
  >&2 echo "${RED}Error: docker-compose could not be found${RESET}"
  exit 1
fi

# Get the Docker Compose version
composeVer=$(docker-compose version --short)
if [[ -z "$composeVer" ]]; then
  >&2 echo "${RED}Error: Could not determine docker-compose version${RESET}"
  exit 1
fi

# Cache Options
isUpdated=false
selfCache="$HOME/.cache/$selfApp/${composeVer-unknown}" &&
  [[ "$OSTYPE" == "darwin"* ]] &&
  selfCache="$HOME/Library/Caches/$selfApp/${composeVer-unknown}"
cacheFile="$selfCache/compose-options.json"

# If the cache directory exists, pull.
repoDir="$selfCache/repo/compose-docs"
if [[ -d "$repoDir" ]]; then
  prevHash=$(docs-get-hash)
  if ! docs-repo-pull; then
    retval=$?
    >&2 echo "${RED}Error: Could not pull docker/compose repo!"
    exit $retval
  fi
  newHash=$(docs-get-hash)
  if [[ "$prevHash" != "$newHash" ]]; then
    isUpdated=true
  fi
else
  isUpdated=true
  if ! docs-repo-clone; then
    retval=$?
     >&2 echo "${RED}Error: Could not clone docker/compose repo!${RESET}"
    exit $retval
  fi
fi

if $isUpdated || [[ ! -f "$cacheFile" ]]; then
  target_dir="$repoDir/docs/reference"

  # Parse docker_compose.yaml to get the clink array
  clink_array=($(yq e '.clink[]' "$target_dir/docker_compose.yaml"))

  # Initialize empty JSON objects
  subcommands="{}"
  result="{}"

  # Loop through each file in the clink array
  for file in $clink_array; do
    # Extract the subcommand name from the filename (docker_compose_<subcommand>.yaml)
    subcommand=$(basename "$file" .yaml | sed 's/docker_compose_//')

    # Omit $cmdBlock subcommands
    if [[ " ${cmdBlock[@]} " =~ " ${subcommand} " ]]; then
      # echo "Skipping subcommand: $subcommand (in cmdBlock)"
      continue
    fi

    # Parse Options
    options_json=$(
      yq e '(.options // [])[] | select(.deprecated != true and .hidden != true and .experimental != true and .experimentalcli != true) | .description |= sub("(?s):\n\s*'\''table'\''.*", "") | [ .option, .value_type, .default_value, .description, .shorthand ]' "$target_dir/$file" -o=json |
        jq -s '
        map(select(. != null))
        | map({
            (.[0] | tostring): {
              "value_type": (if .[1] == null or .[1] == "null" then "" else .[1] | tostring end),
              "default_value": (if .[2] == null or .[2] == "null" then null else .[2] | tostring end),
              "description": (if .[3] == null or .[3] == "null" then "" else .[3] | tostring | sub("^\\s+"; "") | sub("\\s+$"; "") end),
              "shorthand": (if .[4] == null or .[4] == "null" then null else .[4] | tostring end),
              "repeatable": (if .[1] == "stringArray" then true else false end),
              "expects_value": (if .[1] == "bool" then false else true end),
            }
          })
        | add // {}'
    )

    # Parse Short Description
    description=$(yq e '.short // ""' "$target_dir/$file")

    # Parse Usage
    usage=$(
      yq e '.usage // "" | sub("\n\s*", "|") | sub("\|-", "") | sub("docker compose ", "vat ")' -o=json "$target_dir/$file" |
        jq -r '.'
    )

    # Add to option to the subcommands JSON object
    subcommands=$(jq --arg subcommand "$subcommand" --arg desc "$description" --arg usage "$usage" --argjson options "$options_json" '. + {($subcommand): { "description": $desc, "usage": $usage, "options": $options }}' <<<"$subcommands")
  done

  # Parse global options
  options_json=$(
    yq e '(.options // [])[] | select(.deprecated != true and .hidden != true and .experimental != true and .experimentalcli != true) | .description |= sub("(?s):\n\s*'\''table'\''.*", "") | .description |= sub("\n\s*", " ") | [ .option, .value_type, .default_value, .description, .shorthand ]' "$target_dir/docker_compose.yaml" -o=json |
      jq -s '
      map(select(. != null))
      | map({
          (.[0] | tostring): {
            "value_type": (if .[1] == null or .[1] == "null" then "" else .[1] | tostring end),
            "default_value": (if .[2] == null or .[2] == "null" then null else .[2] | tostring end),
            "description": (if .[3] == null or .[3] == "null" then "" else .[3] | tostring | sub("^\\s+"; "") | sub("\\s+$"; "") end),
            "shorthand": (if .[4] == null or .[4] == "null" then null else .[4] | tostring end),
            "repeatable": (if .[1] == "stringArray" then true else false end),
            "expects_value": (if .[1] == "bool" then false else true end),
          }
        })
      | add // {}'
  )

  # Put the JSON together
  result=$(jq --argjson sc "$subcommands" --argjson opt "$options_json" '. | .commands = $sc | .options = $opt' <<<"$result")
  result=$(jq --slurpfile extra "$selfDir/../share/commands.json" '.commands = ((.commands + $extra[0].commands) | to_entries | sort_by(.key) | from_entries)' <<<"$result")

  # Save the final JSON to a file
  echo "$result" >"$cacheFile"
fi

# Display JSON
jq '.' "$cacheFile"