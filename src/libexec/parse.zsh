#!/usr/bin/env zsh

# @file parse.zsh
# @brief Parses arguments for Docker Compose
# @description Parses Docker Compose arguments and environment variables specific to
# locating the Docker Compose config and environment variable files. The same logic
# followed by the Docker Compose CLI is used to determine the precedence of config files.
# 
# To further support environments where Docker Compose configurations are kept within 
# a specific directory structure, two additional environment variables have been added:
#
# 1. COMPOSE_ROOT - Specifies the root directory for all Docker Compose configurations
# 2. COMPOSE_DIR  - Mimics the behavior of the --project-directory flag
#
# These variables do not interfere with the standard Docker Compose CLI behavior and are
# only used when file location flags are not provided, and the stack name is hinted with
# either the --project-name flag or COMPOSE_PROJECT_NAME environment variable. In this
# case, the parser will attempt to locate the Docker Compose config file within the
# COMPOSE_ROOT/COMPOSE_PROJECT_NAME directory.
#
# @option --file, -f <file> Specify a compose file
# @option --project-name, -p <name> Specify an alternate project name
# @option --env-file <file> Specify an alternate environment file
# @option --project-directory <dir> Specify an alternate working directory
# @option --env <key=value> Specify an environment variable to set (only valid for 'exec' type commands)
# @option --json Output the parsed arguments and environment variables in JSON format
# @option --help Show help
# @option --version | -V Show version
#
# @author AMJones <am@jonesiscoding.com>
# @license 
# @version ##VERSION##
# @revision
# @built

## region ########## Command Init

selfDir=$(cd -- "$(dirname -- "$0")" && pwd -P)
selfLib=$( cd "${selfDir/\/libexec//lib}" && pwd -P)
selfName="parse"
selfVer="##VERSION##"
selfSchema=$($selfDir/cli-schema.zsh)

## endregion ####### Command Init

## region ########## Object Functions

# @brief Applies JQ filters to the JSON string provided via stdin and outputs the result
# @arg $@ string JQ filter(s) to apply
# @stdout string Result of applying the JQ filter to the JSON string  
function object() {
  # Get Input
  local in
  if [[ ! -t 0 ]]; then
    in=$(cat)
  fi

  # Separate Flags
  local flags=()
  local query=""
  for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
      flags+=("$arg")
    else
      query="$arg"
    fi
  done

  # Run the check using the correct input source
  if output=$(jq "${flags[@]}" "$query" <<< "$in" 2>/dev/null); then
    case "${output##[[:space:]]#}" in
      \{*\}|\[*\])
        # It's an object/array. Re-run preserving flags (like -c).
        jq "${flags[@]}" "$query" <<< "$in"
        ;;
      *)
        # It's a primitive. Force raw output to strip quotes.
        jq "${flags[@]}" -r "$query" <<< "$in"
        ;;
    esac
    return 0
  else
    return $?
  fi
}

# @brief Parses the current arguments object using JQ and outputs the result
# 
# @arg $@ string[] Flags and filters to query the $parsed arguments object
# @stdout string Result of applying the JQ filter to the parsed arguments object
function obj-args() {
  object "$@" <<< "$parsed"
}

# @brief Parses the current arguments object using JQ and outputs the result as an array
# @arg $@ string[] Flags and filters to query the $parsed arguments object
# @stdout string   Space-separated string to import into a ZSH array
function obj-args-array() {
  # Separate Flags
  local flags=()
  local query=""
  for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
      flags+=("$arg")
    else
      query="$arg"
    fi
  done

  # Try the query, see if the result is an array.
  local output=$(obj-args "${flags[@]}" "$query" 2>/dev/null)
  if [[ -n "$output" ]]; then
    case "${output##[[:space:]]#}" in
      \[*\])
        echo ${(f)"$(obj-args -r -c "${flags[@]}" "${query}[]")"}
        # It's an array, add trailing [] to the query and re-run with -r -c
        ;;
      *)
        # Otherwise, run the query as-is
        obj-args "$@"
        ;;
    esac
  fi
}

## endregion ####### Object Functions

## region ########## Schema Map Functions

# @brief Generates flag => expects_value mapping
# @arg string JSON path string (e.g., ".options" or ".attach.options")
# @stdout string Space-separated string of --flag bool to import into a ZSH array
get_expects_value_map() {
  local json_path="$1"
  jq -r "${json_path} | to_entries[] | \"--\(.key) \(.value.expects_value)\"" <<< "$selfSchema"
}

# @brief Generates flag => repeatable mapping
# @arg string JSON path string  (e.g.,  ".options" or  ".attach.options")
# @stdout string Space separated string of  --flag bool to import into a ZSH array
get_repeatable_map() {
  local json_path="$1"
  jq -r "${json_path} | to_entries[] | \"--\(.key) \(.value.repeatable)\"" <<< "$selfSchema"
}

# @brief Generates short -> long flag mapping (ignores entries with null shorthand)
# @arg string JSON path string  (e.g.,  ".options" or  ".attach.options")
# @stdout string Space separated string of  flag alias => long to import into a ZSH array
get_canonical_map() {
  local json_path="$1"
  jq -r "${json_path} | to_entries[] | select(.value.shorthand != null) | \"-\(.value.shorthand) --\(.key)\"" <<< "$selfSchema"
  jq -r ".aliases // [] | to_entries[] | \"--\(.key) --\(.value)\"" <<< "$selfSchema"
}

# @brief Extracts valid subcommand names
# @noargs
# @stdout string Space-separated string of valid subcommands to import into a ZSH array
get_valid_subcommands() {
  jq -r '.commands | keys[]' <<< "$selfSchema"
}

## endregion ####### Schema Map Functions

## region ########## Flag Handling Functions

# @brief Normalizes the given short or alias flag to its canonical long form, or returns the original if not recognized
# @arg $1 string Flag to normalize (e.g., --file or -f)
# @stdout string Normalized flag (e.g., --file) or the original input if not recognized
function normalize-flag() {
  case "$1" in
    --* | -*)
      flagName="$1"
      if [[ -n "$canonical[$flagName]" ]]; then
        flagName="$canonical[$flagName]"
      fi
      ;;
  esac

  echo "$flagName" && return 0
}

# @brief Validates the given flag and its value against the expected schema
# @arg $1 string Flag to validate (e.g., --file or -f)
# @arg $2 string Value associated with the flag (if any)
# @exitcode 0 Valid flag and value
# @exitcode 1 Valid flag but missing required value
# @exitcode 2 Unrecognized flag
# @exitcode 3 Recognized subcommand
function validate-flag() {
  case "$1" in
    --yaml | --args)
      return 0
      ;;
    --* | -*)
      flagName="$1"
      # Normalize the flag
      if [[ -n "$canonical[$flagName]" ]]; then
        flagName="$canonical[$flagName]"
      fi
      # Determine if the flag expects a value and validate accordingly
      if [[ -n "$expects_value[$flagName]" ]]; then
        if [[ "$expects_value[$flagName]" != "true" ]]; then
          # Boolean Flag: No value expected
          return 0
        elif [[ -n "$2" && "$2" != -* ]]; then
          # String Flag: Value provided
          return 0
        else
          # String Flag: Value missing
          return 1
        fi
      else
        # Unrecognized Flag
        return 2
      fi
      ;;
    * )
     if [[ " ${valid_subcommands[*]} " =~ "[[:<:]]$1[[:>:]]" ]]; then
       return 3
     elif [[ " ${services[*]} " =~ "[[:<:]]$1[[:>:]]" ]]; then
       return 4
     fi

      return 2
    ;;
  esac
}

## endregion ####### Flag Handling Functions

## region ########## JSON Setter Functions

# @brief Sets a repeatable flag in the parsed JSON object
# @arg $1 string Flag name (e.g., --file)
# @arg $2 string Value to append to the flag's list
# @sets $parsed JSON object with the updated repeatable flag
function set-repeatable() {
  local prefix="global"
  local key="${1##-}"
  local val="$2"

  [[ ! -t 0 ]] && prefix=$(cat)
  parsed=$(jq \
    --arg prefix "$prefix" \
    --arg k "${key##-}" \
    --arg v "$val" \
    '
    ($prefix | split(".")) as $path |
    ($path + [$k]) as $full |
    (getpath($path) // {}) as $parent |
    (($parent[$k] // []) + [$v]) as $new_list |
    ($parent | .[$k] = $new_list) as $new_parent |
    setpath($path; $new_parent)
    ' <<< "$parsed")
}

# @brief Sets a string flag in the parsed JSON object
# @arg $1 string Flag name (e.g., --file)
# @arg $2 string Value to set for the flag
# @sets $parsed JSON object with the updated string flag
function set-string() {
  local prefix="global"
  local key="${1##-}"
  local val="$2"

  [[ ! -t 0 ]] && prefix=$(cat)
  parsed=$(echo "$parsed" | jq \
    --arg prefix "$prefix" \
    --arg k "${key##-}" \
    --arg v "$val" \
    '($prefix | split(".")) as $path |
    setpath($path; getpath($path) // {}) |
    setpath($path + [$k]; $v)')
}

# @brief Sets a boolean flag in the parsed JSON object
# @arg $1 string Flag name (e.g., --file)
# @sets $parsed JSON object with the updated boolean flag
function set-boolean() {
  local prefix="global"
  local key="${1##-}"
  local val=true

  [[ ! -t 0 ]] && prefix=$(cat)
  parsed=$(echo "$parsed" | jq \
    --arg prefix "$prefix" \
    --arg k "${key##-}" \
    --argjson v "$val" \
    '($prefix | split(".")) as $path |
    setpath($path; getpath($path) // {}) |
    setpath($path + [$k]; $v)')
}

## endregion ####### JSON Setter Functions

## region ########## Docker File Functions

# @brief Finds the first Docker Compose config file in the given directory or parents
# @arg $1 string Directory to start searching from
# @stdout string Path to the found Docker Compose config file, or empty if not found
# @exitcode 0 Success
# @exitcode 1 Failure
function find-compose-file() {
  local target=$(cd "${1}" && pwd) || return 1
  local curr="$target"

  while [[ -n "$curr" ]]; do
    for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
      if [[ -f "$curr/$f" ]]; then
        [[ "$curr" == "$target" ]] && echo "./$f" || echo "$curr/$f"
        return 0
      fi
    done
    # ZSH-native way to get the parent directory (drops the trailing element)
    [[ "$curr" == "/" ]] && break
    # shellcheck disable=SC2154
    curr="${curr:h}"
  done
  return 1
}

# @brief Parse the given .env file for relevant variables
# @arg $1 string Absolute path to .env file
# @sets $env COMPOSE_PATH_SEPARATOR, COMPOSE_PROJECT_NAME, COMPOSE_FILE, COMPOSE_DISABLE_ENV_FILE, COMPOSE_DIR keys.
function load-env() {
  local envFile="$1"

  # Skip if the file doesn't exist or is disabled
  if [[ ! -f "$envFile" ]]; then
    return
  fi

  for yqKey in "COMPOSE_PATH_SEPARATOR" "COMPOSE_PROJECT_NAME" "COMPOSE_FILE" "COMPOSE_DISABLE_ENV_FILE" "COMPOSE_DIR"
  do
    export yqKey
    env[$yqKey]=$(yq -r -p=props -o=y '.[env(yqKey)] // ""' "$envFile")
  done
}

## endregion ####### Docker File Functions

## region ########## Environment Setter Functions

# @brief Sets the COMPOSE_DIR environment variable based on precedence rules
# @sets $env[COMPOSE_DIR]
function set-compose-dir() {
  local file="${cfgFiles[1]}"
  local cwd=$(pwd)
  local projName=$env[COMPOSE_PROJECT_NAME]
  local rootDir=$env[COMPOSE_ROOT]

  if [[ -n "$flagDir" && "$flagir" == /* ]]; then
    # 1: Flag If Given & Absolute
    env[COMPOSE_DIR]="$flagDir"
  elif [[ -n "$flagDir" ]]; then
   # 2: Flag If Given & Relative
    env[COMPOSE_DIR]="${COMPOSE_ROOT}/${flagDir}"
  elif [[ -n "$file" && "$file" == /* ]]; then
    # 3: Directory of the first Compose file, if given and absolute
    env[COMPOSE_DIR]=$(dirname "${cfgFiles[1]}")
  elif [[ -n "$file" && -f "${cwd}/${file}" ]]; then
    # 4: PWD, if the first Compose file is given and exists in PWD.
    env[COMPOSE_DIR]="$cwd"
  elif [[ -n "$file" && -n "$rootDir" && -n "$projName" && -f "${rootDir}/${projName}/${file}" ]]; then
    # 5: COMPOSE_ROOT + COMPOSE_PROJECT_NAME, if the first Compose file is given and exists in PWD.
    env[COMPOSE_DIR]="${rootDir}/${projName}"
  elif [[ -n "$COMPOSE_DIR" ]]; then
    # 6: COMPOSE_DIR, if set
    env[COMPOSE_DIR]="$COMPOSE_DIR"
  elif [[ -n "$rootDir" && -n "$projName" && -d "${rootDir}/${projName}" ]]; then
   # 7: COMPOSE_ROOT + COMPOSE_PROJECT_NAME, if the directory exists
   env[COMPOSE_DIR]="${rootDir}/${projName}"
  else
    # 8: Present Directory
    env[COMPOSE_DIR]="$cwd"
  fi
}

## endregion ####### Environment Setter Functions

## region ########## Parse Global Flags

# Initialize the data containers
parsed="{}"
typeset -A env
typeset -a services
serviceName=""
flagArgs=false
flagYaml=false
flagVat=false

# Check for Pipeline Handshake
if [[ ! -t 0 ]] && read -r -t 1 stdin_handshake && [[ "$stdin_handshake" == "VAT_PIPE_INIT" ]]; then
  # PIPELINE RUN: No Color JSON output
  flagArgs=false; flagYaml=false; flagVat=true; export NO_COLOR=1
  # Reset stdin Attachment
  exec 0</dev/tty
fi

# Initialize and absorb the function tokens into Associative Arrays
local global_path=".options"
typeset -A expects_value=(     ${(z)$(get_expects_value_map "$global_path")} )
typeset -A is_repeatable=(     ${(z)$(get_repeatable_map    "$global_path")} )
typeset -A canonical=(         ${(z)$(get_canonical_map     "$global_path")} )
typeset -a valid_subcommands=( ${(f)$(get_valid_subcommands)} )

# Handle Global Flags
while [[ -n "$1" ]]; do
  validate-flag "$@"
  retval=$?
  if [[ $retval -ne 0 ]]; then
    if [[ $retval -eq 1 ]]; then
      # 1 = Missing Value
      echo "Error: $1 missing required value." >&2
      exit 1
    elif [[ $retval -eq 3 ]]; then
      # 3 = Not a Flag; Subcommand Name
      subCommand="$1"
    elif [[ $retval -eq 4 ]]; then
      # 4 = Not a Flag; Service Name
      serviceName="$1"
    else
      # 2 = Unrecognized; pass back into stdin
      in+=($1)
    fi
  else
    # Normalize the flag
    flagName=$(normalize-flag "$@")
    case "$flagName" in
      --args)
        flagArgs=true
        ;;
      --yaml)
        flagYaml=true
        ;;
      *)
        # Docker-Specific Flags (set in $parsed)
        if [[ "$expects_value[$flagName]" == "true" ]]; then
          if [[ "$is_repeatable[$flagName]" == "true" ]]; then
            set-repeatable "$flagName" "$2"
          else
            set-string "$flagName" "$2"
          fi
          shift
        else
          set-boolean "$flagName"
        fi
        ;;
    esac
  fi
  shift
done
set -- "${in[@]}"

## endregion ####### Parse Global Flags

## region ########## Resolve Environment

# Default Environment
env[COMPOSE_FILE]="$COMPOSE_FILE"
env[COMPOSE_ENV_FILES]="$COMPOSE_ENV_FILES"
env[COMPOSE_PROJECT_NAME]="$COMPOSE_PROJECT_NAME"
env[COMPOSE_PATH_SEPARATOR]="${COMPOSE_PATH_SEPARATOR:-:}"
env[COMPOSE_DIR]="$COMPOSE_DIR"
env[COMPOSE_DISABLE_ENV_FILE]="${COMPOSE_DISABLE_ENV_FILE:-0}"
env[COMPOSE_ROOT]="$COMPOSE_ROOT"

# Normalize COMPOSE_DISABLE_ENV_FILE
if [[ $env[COMPOSE_DISABLE_ENV_FILE] == 1 ]] || [[ $env[COMPOSE_DISABLE_ENV_FILE] == "true" ]]; then
  env[COMPOSE_DISABLE_ENV_FILE]=true
else
  env[COMPOSE_DISABLE_ENV_FILE]=false
fi

# Flag Overrides COMPOSE_PROJECT_NAME
flagName=$(obj-args '.global."project-name" // empty')
[[ -n $flagName ]] && env[COMPOSE_PROJECT_NAME]="$flagName"

# Flag Overrides COMPOSE_DIR
flagDir=$(obj-args '.global."project-directory" // empty')
[[ -n $flagDir ]] && env[COMPOSE_DIR]="$flagDir"

# Load Environment Files
envFiles=($(obj-args-array '.global."env-file"'))
if ! $env[COMPOSE_DISABLE_ENV_FILE]; then
  if [[ ${#envFiles[@]} -eq 0 && -n "$env[COMPOSE_ENV_FILES]" ]]; then
    envFiles=(${(@s:/:)env[COMPOSE_ENV_FILES]})
  fi

  if [[ ${#envFiles[@]} -eq 0 ]]; then
    set-compose-dir
    if [[ -f "${env[COMPOSE_DIR]}/.env" ]]; then
      envFiles=("./.env")
    fi
  fi

  if [[ ${#envFiles[@]} -gt 0 ]]; then
    # Parse each envFile
    for envFile in "${envFiles[@]}"; do
      load-env "$envFile"
    done
  fi
fi

# Load Compose Config Files
cfgFiles=($(obj-args-array '.global.file'))
# typeset -p env
if [[ ${#cfgFiles[@]} -eq 0 && -n $env[COMPOSE_FILE] ]]; then
  cfgFiles=(${(@s:/:)env[COMPOSE_FILE]})
elif [[ -n $flagDir ]]; then
  cfgFiles=("$(find-compose-file "$flagDir")")
fi

# Set COMPOSE_DIR now that the rest is populated
set-compose-dir

# If no Compose files were found, try to find one in the COMPOSE_DIR
if [[ ${#cfgFiles[@]} -eq 0 ]] && [[ -n "$env[COMPOSE_DIR]" ]]; then
  cfgFiles=("$(find-compose-file "$env[COMPOSE_DIR]")")
fi

# Remove empty entries from envFiles and cfgFiles
envFiles=(${(M)${envFiles##[[:space:]]#}:#?*})
cfgFiles=(${(M)${cfgFiles##[[:space:]]#}:#?*})
# Update JSON
parsed=$(jq \
  --argjson envFiles "$(jq -n '$ARGS.positional' --args "${envFiles[@]}")" \
  --argjson cfgFiles "$(jq -n '$ARGS.positional' --args "${cfgFiles[@]}")" \
  '.global."env-file" = $envFiles | .global.file = $cfgFiles' <<< "$parsed")

## endregion ####### Resolve Environment

## region ########## Parse Subcommand & Remaining Flags

# Get Services from Compose File
if [[ ${#cfgFiles[@]} -gt 0 ]]; then
  services=($(yq ea '. as $item ireduce ({}; . * $item) | .services | keys | .[]' "${cfgFiles[@]}"))
fi

# Handle Subcommand Flags
if [[ -n $subCommand ]]; then
  parsed=$(echo "$parsed" | jq --arg k "$subCommand" '.subcommand = $k')
  sub_path=".commands.${subCommand}.options"
  expects_value=(     ${(z)$(get_expects_value_map "$sub_path")} )
  is_repeatable=(     ${(z)$(get_repeatable_map    "$sub_path")} )
  canonical=(         ${(z)$(get_canonical_map     "$sub_path")} )
  in=()
  while [[ -n "$1" ]]; do
    validate-flag "$@"
    retval=$?
    if [[ $retval -ne 0 ]]; then
      if [[ $retval -eq 1 ]]; then
        # 1 = Missing Required Value
        echo "Error: $1 missing required value." >&2
        exit 1
      elif [[ $retval -eq 4 ]]; then
        # 4 = Not a Flag; Service Name
        serviceName="$1"
      else
        # 2 = Unrecognized; pass back into stdin
        in+=($1)
      fi
    else
      # Normalize Flag
      flagName=$(normalize-flag "$@")
      # Handle Flag
      case "$flagName" in
        *)
          if [[ "$expects_value[$flagName]" == "true" ]]; then
            if [[ "$is_repeatable[$flagName]" == "true" ]]; then
              set-repeatable "$flagName" "$2" <<< "$subCommand"
            else
              set-string "$flagName" "$2" <<< "$subCommand"
            fi
            shift
          else
            set-boolean "$flagName" <<< "$subCommand"
          fi
          ;;
      esac 
    fi
    shift
  done
  set -- "${in[@]}"
fi

# Parse remaining Values
while [[ -n "$1" ]]; do
  parsed=$(jq --arg v "$1" '.rest |= (. // []) + [$v]' <<< "$parsed")
  shift
done

if [[ -n "$serviceName" ]]; then
  parsed=$(echo "$parsed" | jq --arg svc "$serviceName" '.service = $svc')
fi

# Handle Special Flags
flagQ=$(obj-args '.global.quiet // false')
flagV=$(obj-args '.global.verbose // false')
flagVer=$(obj-args '.global.version')
flagH=$(obj-args '.global.help // false')  

## endregion ####### Parse Subcommand & Remaining Flags

## region ########## Output 

# Handle Output
if $flagYaml; then
  # YAML Output
  $flagVat && parsed=$(jq --argjson j "$parsed" '.arguments = $j' <<< "{}")
  $flagQ && export NO_COLOR=1
  yq -P -o=y <<< "$parsed"
elif $flagArgs; then
  # Argument Output
  args=()
  # gArgs=($(obj-args '.global | to_entries[] | "--\(.key) \(.value)"'))
  gArgs=($(obj-args '[ .global | to_entries[] | if (.value | type) == "array" then "--\(.key) \(.value[])" else "--\(.key) \(.value)" end ] | join(" ")'))
  cArgs=($(obj-args --arg sc $subCommand '.$sc | to_entries[] | \"--\(.key) \(.value)\"'))
  rArgs=($(obj-args '.rest[]'))
  args=("${gArgs[@]}" "${cArgs[@]}")
  [[ -n "$subCommand" ]] && args+=($subCommand)
  [[ -n "$serviceName" ]] && args+=($serviceName)
  args+=("${rArgs[@]}")
  echo "${args[@]}"
else
  # JSON Output
  # Handle VAT Pipeline Output
  $flagVat && parsed=$(jq -L "" --argjson j "$parsed" '.arguments = $j' <<< "{}")
  # Make sure to disable color output if the quiet flag is set
  $flagQ && export NO_COLOR=1
  jq -S . <<< "$parsed"
fi

## endregion ####### Output
