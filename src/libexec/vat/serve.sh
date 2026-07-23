#!/bin/zsh

# @file serve4
# @brief Serves a vat container recipe
# 
# @flag --up                    Start Server & Show Logs          
# @flag --start                 Start Server                      
# @flag --stop                  Stop Server                       
# @flag --shell                 Connect to Shell Session          
# @flag -s, --service <service> Service Name                      
# @flag -q, --quiet             Suppress all output               
# @flag -v, --verbose           Enable verbose output             
# @flag -h, --help              Show this help message and exit.  
# @flag -V, --version           Display the version of the script.
# 
# @arg $1 string Subcommand to Run
# 
# @exitcode 5 Docker Error
#
# @author
# @license
# @version ##VERSION##
# @revision
# @built

## region ############################################## Command Setup

selfDir=$(cd -- "$(dirname -- "$0")" && pwd -P)
selfLib=$( cd "${selfDir/\/libexec//lib}" && pwd -P)
selfName="serve4"
selfVer="##VERSION##"

# Exit Codes
exitDocker=5  # Docker Error

# Usage Declaration
read -r -d '' selfUsage <<EOF
$selfName v$selfVer
Serves a vat container recipe

Usage: 
  $selfName [options] <args>

Arguments:
   $1 string Subcommand to Run

Options:
   --up                    Start Server & Show Logs          
   --start                 Start Server                      
   --stop                  Stop Server                       
   --shell                 Connect to Shell Session          
   -s, --service <service> Service Name                      
   -q, --quiet             Suppress all output               
   -v, --verbose           Enable verbose output             
   -h, --help              Show this help message and exit.  
   -V, --version           Display the version of the script.

Exit Codes:
   5 Docker Error
EOF

## endregion ########################################### Command Setup

## region ############################################## Functions

# shellcheck source="../../lib/_style.sh"
source "$selfLib/../_style.sh"
source "$selfLib/../_compose.sh"

# @brief Shows Script Version Info
# @noargs
function show_version() {
  if $flagQ; then
    echo "$selfVer"
  else
    echo "$selfName v$selfVer"
    [[ -n "$selfRepo" ]] && echo "($selfRepo)"
  fi
}

# @brief Shows Script Usage Info
# @noargs
function show_usage() {
  if [[ -z "$selfUsage" ]] && ! $flagQ; then
    show_version
  elif ! $flagQ; then
    echo "$selfUsage"
  fi
}

function compose_stacks() {
  local root curDir aData
  root=${1:-$COMPOSE_ROOT}
  curDir=$(pwd)
  aData="{}"
  for dir in "$root"/*/; do
    # Skip if not a directory
    [[ -d "$dir" ]] || continue
    
    # Find docker compose file using the compose_find function
    compose_file=$(compose_find "$dir")

    # Skip if no compose file found
    [[ -n "$compose_file" ]] || continue
  done
}

function compose_services() {
  local compose_file dir
  compose_file="$1"
  dir=$(dirname "$compose_file")
  config=$(cd "$dir"; docker compose config 2>/dev/null)
  [[ -n "$config" ]] || return 1

  yq -oj '.services' <<< "$config" | jq --arg path "$compose_file" 'to_entries | map({ service: .key, image: .value.image, config: $path })'
}

function compose_ls() {
  local currDir dir dName compose_file services_json root

  root=${1:-$COMPOSE_ROOT}
  curDir=$(pwd)
  aData="{}"
  for dir in "$root"/*/; do
    # Skip if not a directory
    [[ -d "$dir" ]] || continue
    
    # Get the basename of the directory
    dirname=$(basename "$dir")
    
    # Find docker compose file using the compose_find function
    compose_file=$(compose_find "$dir" | sed "s|^$root/||")

    # Skip if no compose file found
    [[ -n "$compose_file" ]] || continue

    lData=$(compose_services "$compose_file")

    config=$(cd "$dir"; docker compose config 2>/dev/null)
    [[ -n "$config" ]] || continue

    # lData=$(yq -oj '.services' <<< "$config" | jq --arg path "$compose_file" 'to_entries | map({ service: .key, image: .value.image, config: $path })')
    # aData=$(jq --arg k "$dirname" --argjson arr "$lData" '.[$k] = $arr' <<< "$aData")
    lData=$(yq -oj '.services' <<< "$config" | jq --arg path "$compose_file" 'to_entries | map({ service: .key, image: .value.image, config: $path })')

    # Update the object using a safe heredoc or direct string insertion
    aData=$(jq --arg k "$dirname" --argjson arr "$lData" '.[$k] = $arr' <<< "$aData")
  done

  echo "$aData"
  return 0
}

function compose_subcommands() {
  docker compose --help | \
  grep -E "^[[:space:]]+[a-zA-Z]" | \
  awk '{
    # Remove leading whitespace and store the command
    cmd = $1
    # Get the description (everything after the command)
    desc = ""
    for(i=2; i<=NF; i++) {
      if(desc == "") {
        desc = $i
      } else {
        desc = desc " " $i
      }
    }
    print "{\"command\": \"" cmd "\", \"description\": \"" desc "\"}"
  }' | \
  jq -R 'fromjson' | \
  jq -s 'map({command, description})'
}

cmdSpecial='["version", "cp", "ls", "shell", "exec", "port", "run"]'
cmdBlock='["bridge", "commit", "convert", "create", "export", "push", "rm", "scale", "wait", "watch"]'
function serve_commands() {
  local unfiltered filtered

  unfiltered=$(compose_subcommands)
  filtered_result=$(jq \
  --argjson remove "$cmdBlock" \
  --argjson special "$cmdSpecial" \
  '. | map(select(.command | IN($remove[]) | not)) 
  | map(.special = (.command | IN($special[])))' <<< "$unfiltered")

  shellCmd=$(jq '.command = "shell"' <<< "{}")
  shellCmd=$(jq '.description = "Enter a shell session in a container"' <<< "$shellCmd")
  shellCmd=$(jq '.special = true' <<< "$shellCmd")
  
  importCmd=$(jq '.command = "import"' <<< "{}")
  importCmd=$(jq '.description = "Import a stack into Docker Desktop."' <<< "$shellCmd")
  importCmd=$(jq '.special = true' <<< "$shellCmd")

  filtered_result=$(jq --argjson item "$shellCmd" '. + [$item]' <<< "$filtered_result" )
  filtered_result=$(jq --argjson item "$importCmd" '. + [$item]' <<< "$filtered_result" )
  echo "$filtered_result"
}

function show_ls() {
  local data json
  data=$(compose_ls $1)
  if [[ -z "$data" ]]; then
    echo "No services found in $1" | out error
    return 1
  fi

  json=$(jq 'to_entries | map(.key as $stack | .value[] | . + {stack: $stack})' <<< "$data")
  echo ""
  if [[ "$COMPOSE_ROOT" == "$1" ]]; then
    echo "${CYAN}Config Paths are relative to COMPOSE_ROOT${RESET} ($1)"
  else
    echo "${CYAN}Config Paths are relative to:${RESET} $1"
  fi
  echo ""
  table <<< "$json"
  echo ""
}

isMacOs=$(uname | grep -q "Darwin" && echo "true" || echo "false")
[[ -z "$COMPOSE_ROOT" ]] && COMPOSE_ROOT="/home"
$isMacOs && COMPOSE_ROOT="$HOME/Docker"

## endregion ########################################### Functions

## region ############################################## Argument Handling

# Boolean Flag Initial Values
read -r flagUp flagStart flagStop flagShell flagQ flagV flagH flagVer <<< "false false false false false false false false"

# String Flag Defaults
flagS=""; flagEnv="prod"; 

# Process Flags
in=()
while [[ "$1" != "" ]]; do
  case "$1" in
    --up )             argCmd="up"       ;;  
    --start )          argCmd="start"    ;;  
    --stop )           argCmd="stop";    ;;  
    --shell )          argCmd="shell";   ;;
    --stack )          argStack=$2; shift  ;;  
    --service )        argSvc=$2; shift  ;;  
    --env-file )       flagEnvFile+=("$2"); shift ;;
    -f | --file )      flagFile+=("$2"); shift ;;
    -q | --quiet )     flagQ=true;       ;;  
    -v | --verbose )   flagV=true;       ;;  
    -h | --help )      flagH=true;       ;;  
    -V | --version )   flagVer=true;     ;;  
    * )                in+=("$1");       ;;  
  esac
  shift
done
set -- "${in[@]}"

# Lock Values of Boolean Flags
readonly flagQ flagV flagH flagVer

# Set Values of Argument Variables
if [[ -z "$argCmd" ]]; then
  argCmd="$1"
  shift;
fi

# Validate Command
cmds=$(serve_commands)
tCmd=$(jq -r '.[] | select(.command == $target) // empty' <<< "$cmds")
[[ -z "$tCmd" ]] && show_usage && exit 1

# Simple Command Routing
case "$argCmd" in
  version ) show_version; exit 0; ;;
  help    ) show_usage;   exit 0; ;;
  ls      ) show_ls;      exit 0; ;;
  ps      ) show_ps;      exit 0; ;;
esac

# Default argStack (if needed & possible)
if [[ -z "$argStack" ]]; then
  argStack="$1"
  if [[ -n "$argStack" ]] && stack_validate "$argStack"; then
    shift
    if [[ -z "$argSvc" ]]; then
      argSvc=$(echo "$argStack" | awk -F"/" '{print $2}')
    fi
  elif [[ "$PWD/" == "$COMPOSE_ROOT/"* ]]; then
    argStack="${PWD:t}"
  else
    echo "Error: No stack specified and not in a stack directory" >&2 | out error
    exit 1
  fi
elif ! stack_validate "$argStack"; then
  echo "ERROR: Invalid Stack $argStack" >&2 | out error
  exit 1
fi

# Build $flagFile Defaults
composeDir="$COMPOSE_ROOT/$flagStack"
if [[ $#flagFile -eq 0 ]];  then
  file=$(compose_find "$composeDir")
  if [[ -n "$file" ]]; then
    flagFile+="$file"
    localF="${composeDir}/${file:t:r}.override.${file:e}"
    if [[ -f "$localF" ]]; then
      flagFile+="$localF"
    fi
  fi
fi

cEnvFiles=(".env" ".env.local" ".env.override")
for file in ${flagFile[@]}; do
  fDir=$(dirname "$file")
  for envF in ${cEnvFiles[@]}; do
    if [[ -f "$envF" ]]; then
      flagEnvFile+=("$fDir/$envF")
    fi
  done
done

## endregion ########################################### Argument Handling
  
## region ############################################## Post-Argument Handling

# Open Docker Desktop if not open (on macOS)
if $isMacOs; then
  if ! /usr/bin/pgrep -f "Docker.app" >/dev/null 2>&1; then
    echo "Opening Docker Desktop" | spin
    open -a "Docker Desktop"
    xc=1
    while ! docker stats --no-stream >/dev/null 2>&1; do
      sleep 1
      xc=$((xc+1))
      [ "$xc" -gt "30" ] && finish false && exit 1
    done
    finish true
  fi
fi

# Build Arguments for Docker
cArgs=()
for file in ${flagFile[@]}; do
  cArgs+=("-f" "$file")
done

for envF in ${flagEnv[@]}; do
  cArgs+=("--env-file" "$envF")
done

if [[ -n "$argSvc" ]]; then
  cArgs+=("$argSvc")
fi

# If no project name in config, add it as a CLI flag

## endregion ########################################### Post-Argument Handling

## region ############################################## Main Code

# Handle Commands that Require a Service

# Handle Special Commands

# Handle the rest.


case "$argCmd" in
  up | start | stop | pause | unpause | down )
    cwd=$(pwd)
    cd "$composeDir" || exit 1
    if [[ -n "$argSvc" ]]; then
      docker compose "${cArgs[@]}" "$argCmd" "$argSvc" "${@}"
    else 
      docker compose "${cArgs[@]}" "$argCmd" "$argSvc" "${@}"
    fi
    retval=$?
    cd "$cwd"
    exit $retval
    ;;
  import )
    ;;
  shell )        
    ;;
  exec )         flagExec=true;   ;;  
  pull )         argService="$2"; shift ;;
  import )       flagImport=true  ;;
  * )            docker compose $argCmd "${@}" && exit $? ;;
esac

if $flagLs; then
  show_ls
else
  cwd=$(pwd)
  cd "$composeDir" || exit 1
  if $flagShell; then
    doShell "${@}"
  elif $flagImport; then
    cArgs+=("--pull" "--no-start")
    docker compose "${cArgs[@]}" up "${@}"
  else
    docker compose "${cArgs[@]}" "${@}"
  fi

  status=$?
  cd "$cwd" || exit 1
  exit $?
fi

## endregion ########################################### Main Code

