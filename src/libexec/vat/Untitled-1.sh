#!/usr/bin/env zsh

# @file gen
# @brief Generates overrides
# 
# @flag  --algo      <algorithm>  Algorithm to use for SSH key authentication
# @flag  --protocol  <protocol>   Protocol to use for Git clone (if not included in URL)
# 
# @arg  $1  Docker Compose File
# @arg  $2  Local name for vat; must be an available local username
# 
# @exitcode  1  Unknown Error
# @exitcode  5  Bad SSH Algorithm
# @exitcode 10  Not Run With Sudo
# @exitcode 20  Git Authorization Failed
# @exitcode 30  Docker Compose Update Failed
# @exitcode 35  Env Update Failed
# @exitcode 40  Permissions Update Failed
# @exitcode 50  Clone Update Failed
#
# @version ##VERSION##
# @revision
# @built

## region ############################################## Command Setup

selfDir=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P )
selfLib=$( cd "${selfDir/\/libexec//lib}" && pwd -P)
selfName="Ladle Gen"
selfRepo=""
selfVer="##VERSION##"
selfHost=$(hostname -f)
selfDomain=$(hostname -d)
selfFlags=("algo:" "protocol:" )

isMac=$( [[ $OSTYPE = darwin* ]] && echo true || echo false )
cwd=$(pwd)

# Exit Codes
exitError=1    # Unknown Error
exitOption=2   # Bad Flag
exitArg=3      # Missing Argument
exitUrl=4      # Bad Repo URL
exitAlgo=5     # Bad Algorithm
exitSudo=10    # Not Run With Sudo
exitGitAuth=20 # Git Authorization Failed
exitCompose=30 # Docker Compose Update Failed
exitEnv=35     # Env Update Failed
exitPerms=40   # Permissions Update Failed
exitClone=50   # Clone Update Failed

# Usage Declaration
repoUsage=$(echo "($selfRepo)" | sed 's/()//')
read -r -d '' selfUsage <<EOF
$selfName v$selfVer $repoUsage
Scoops a Vat to Serve

Usage: $selfName [options] <args>

Arguments:
  <repo>  Remote repository containing the vat recipe
  <name>  Local name for vat; must be an available local username

Options:
  --algo      <algorithm>  Algorithm to use for SSH key authentication
  --protocol  <protocol>   Protocol to use for Git clone (if not included in URL)

Other Options:
  -q, --quiet          Suppress all output.
  -v, --verbose        Enable verbose output.
  -h, --help           Show this help message and exit.
  -V, --version        Display the version of the script.

Exit Codes:

  1:  Unknown Error
  2:  Bad Flag
  3:  No Docker Compose File Found
  5:  Bad SSH Algorithm
 10:  Not Run With Sudo
 20:  Git Authorization Failed
 30:  Docker Compose Update Failed
 35:  .env Update Failed
 40:  Permissions Update Failed
 50:  Clone Update Failed 
 
EOF

# shellcheck source=../lib/_in.sh
source "$selfLib/_in.sh"

# shellcheck source=../lib/_shell.sh
source "$selfLib/_shell.sh"

# shellcheck source=../lib/_fs.sh
source "$selfLib/_fs.sh"

# shellcheck source=../lib/_fs.sh
source "$selfLib/_compose.sh"

# shellcheck source=../lib/_gum.sh
source "../lib/_gum.sh"

## endregion ########################################### Command Setup

argCompose="$1"
argEnv="$2"

[[ -z "$argCompose" ]] && argCompose="$cwd"

if [[ -d "$argCompose" ]]; then
  argCompose=$(compose_find "$argCompose")
  if [[ ! -f "$argCompose" ]]; then
    echo "No Docker Compose file was found in: $argCompose" | out error
    exit "$exitArg"
  fi
fi

if [[ ! -f $argCompose ]]; then
  echo "No Docker compose file was found at: $argCompose" | out error
  exit "$exitArg"
fi

localDir=$(dirname "$argCompose")
localSrv=$(basename "$localDir")
localCompose="${localDir}/${argCompose:t:r}.override.${argCompose:e}"

# Environment File
[[ -z "$argEnv" ]] && argEnv="${localDir}/.env"

readonly localDir localEnv localCompose argEnv argCompose

export HOST_UID=${HOST_UID:-$(id -u)}
export HOST_GID=${HOST_GID:-$(id -g)}
export COMPOSE_PROXY=${COMPOSE_PROXY:-"proxy-net"}
export COMPOSE_HOST=${COMPOSE_HOST:-"$localSrv.$selfDomain"}

touch "$argEnv" "$localEnv"

# Pre-Pull Images
if ! echo "Pulling Images" | spin compose_pullAll <<< "$argCompose"; then 
  exit "$exitPull"
fi

# Read Original Resources BEFORE Creating Override ---
echo "Reading Resource Limits" | notify
for SERVICE in $(docker compose -f "$argCompose" config --format yaml | yq '.services | keys | .[]'); do
  PREFIX=$(echo "$SERVICE" | tr '[:lower:]' '[:upper:]' | tr '-' '_' | tr '.' '_')
  
  declare -A KEYS
  KEYS["${PREFIX}_CPU_LIMIT"]=".deploy.resources.limits.cpus"
  KEYS["${PREFIX}_MEM_LIMIT"]=".deploy.resources.limits.memory"
  KEYS["${PREFIX}_CPU_RESERVE"]=".deploy.resources.reservations.cpus"
  KEYS["${PREFIX}_MEM_RESERVE"]=".deploy.resources.reservations.memory"

  for KEY in "${!KEYS[@]}"; do
    if [ -n "${!KEY}" ] || grep -q "^${KEY}=" "$argEnv" || grep -q "^${KEY}=" "$localEnv"; then
      continue
    fi

    YAML_PATH=".services.${SERVICE}${KEYS[$KEY]}"
    ORIG_VALUE=$(docker compose -f "$argCompose" config --format yaml | yq "$YAML_PATH" 2>/dev/null || echo "null")

    if [ "$ORIG_VALUE" != "null" ] && [ -n "$ORIG_VALUE" ]; then
      echo "${KEY}=${ORIG_VALUE}" >> "$localEnv"
      echo "  -> Captured original resource: ${KEY}=${ORIG_VALUE}"
    else
      echo "${KEY}=" >> "$localEnv"
    fi
  done
  unset KEYS
done

# --- STEP 4: Standalone Shell Lookup Command (Solves the Parser Bug) ---
# We isolate the command here so yq never has to deal with nested string quotes.
LOOKUP_CMD='sh -c "docker run --rm --entrypoint \"\" \$1 whoami 2>/dev/null || echo \"root\"" --'

# --- STEP 5: Generate the Override Config ---
echo "Generating $localCompose..."
docker compose -f "$argCompose" config --format yaml | yq --arg cmd "$LOOKUP_CMD" '
  .services |= map_values(
    (key | upcase | sub("-", "_") | sub("\.", "_")) as $prefix |
    
    # Base Block: Applied to ALL services universally (Deploy Constraints)
    {"deploy": {
      "resources": {
        "limits": {
          "cpus": "${" + $prefix + "_CPU_LIMIT}",
          "memory": "${" + $prefix + "_MEM_LIMIT}"
        },
        "reservations": {
          "cpus": "${" + $prefix + "_CPU_RESERVE}",
          "memory": "${" + $prefix + "_MEM_RESERVE}"
        }
      }
    }}
    +
    # Build Block: Applied ONLY to services with active filesystem or network touchpoints
    (if (has("volumes") or has("ports")) then
      {"build": {
        "context": ".",
        "dockerfile": "local.Dockerfile",
        "args": {
          "BASE_IMAGE": .image,
          "USER_ID": "${HOST_UID}",
          "GROUP_ID": "${HOST_GID}",
          "ORIGINAL_USER": (exec($cmd + " " + .image) | tr -d "\n\r")
        }
      }}
    else
      {}
    fi)
    +
    # Network/Proxy Block: Applied ONLY if external ports are natively bound
    (if has("ports") then 
      with(.ports; . | ireduce(text; . ) | split(":") | .[-1]) as $target_port |
      {
        "networks": ["${COMPOSE_PROXY}"],
        "ports": [],
        "labels": [
          "caddy=${COMPOSE_HOST}",
          "caddy.reverse_proxy={{" + "upstreams" + "}} " + $target_port
        ]
      }
    else 
      {} 
    fi)
  )
  |
  .networks."${COMPOSE_PROXY}" = {"external": true}
' > "$localCompose"

# Ensure global setup keys are in .env.local if completely missing
for GENERAL_KEY in HOST_UID HOST_GID COMPOSE_PROXY COMPOSE_HOST; do
  if ! grep -q "^${GENERAL_KEY}=" "$argEnv" && ! grep -q "^${GENERAL_KEY}=" "$localEnv"; then
     echo "${GENERAL_KEY}=${!GENERAL_KEY}" >> "$localEnv"
  fi
done

echo "Synchronization complete. Run: COMPOSE_argEnvS=.env,.env.local docker compose up --build"
