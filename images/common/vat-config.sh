#!/bin/bash

## endregion ######################################## Functions

## region ########################################### Variables

s6env="/etc/s6-overlay/env"
try=("/usr/local/bin" "/usr/bin")
excluded=("s6-overlay")
transform=("s#dart\-##")
VAT_ENV_DIR="/etc/vat/env.d"
VAT_EXE_DIR="/etc/vat/exec.d"

## endregion ######################################## Variables

## region ########################################### Functions

# @description Attempts to locate an executable with the given name in the path or at any of the 'try' locations.
# @arg $1 string Executable name
# @stdout string Absolute Path
# @exitcode 0 Success
# @exitcode 1 Failure
function try_which() {
  local iPath t i

  i="$1"
  iPath=$(which "$i")
  if [ -n "$iPath" ]; then
    echo "$iPath" && return 0
  fi

  for t in "${try[@]}"; do
    iPath="${t}/${i}"
    [ -f "$iPath" ] && echo "$iPath" && return 0
  done

  return 1
}

function vat-putenv() {
  local key
  key="$1"
  mkdir -p "${vat_env}"

  printf "%s" "$(cat)" > "${vat_env}/${key}"
}

function vat-putexe() {
  local val file

  val="$(cat)"
  file="$val" && [[ "$file" == /* ]] && file=$(basename "$val")
  mkdir -p "${vat_exec}"

  printf "%s" "$val" > "${vat_exec}/${file}"
}

function get-s6-ver() {
  local tryVer i

  if [ -d "/etc/s6-overlay" ]; then
    tryVer=("/package/admin/s6-overlay/version" "/etc/s6-overlay/version")
    for i in "${tryVer[@]}"; do
      if [ -f "$i" ]; then
        cat "$i"
        return 0
      fi
    done
    if [ -d "/etc/s6-overlay/s6-rc.d" ] || [ -d "/command" ]; then
      echo "3"
      return 0
    else
      echo "2"
      return 0
    fi
  else
    return 1
  fi
}

function get-s6-env-dir() {
  local ver major

  echo "/etc/s6-overlay/env"
  return 0

  ver=$(get-s6-ver)
  if [ -n "$ver" ]; then
    major=$(echo "$ver" | awk -F'.' '{print $1}')
    if [ "$major" -ge 3 ]; then
      echo "/etc/s6-overlay/env"
    else
      echo "/var/run/s6/container_environment"
    fi

    return 0
  fi

  return 1
}

## endregion ######################################## Functions

## region ########################################### Main Code

#
# Input Handling
#
flagInit=false; flagExe=false; flagFinish=false; flagSet=false; flagPrefix=""; args=()
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --set)       flagSet=true; ;;
  --init)      flagInit=true; ;;
  --exec)      flagExe=true; ;;
  --finish)    flagFinish=true; ;;
  --prefix)    flagPrefix="$2"; shift ;;
  *)           args+=("$1")
  esac
  shift
done
set -- "${args[@]}"

# These are only used for --exec and --set, to allow for a prefix
vat_env="${VAT_ENV_DIR:-/etc/vat/env.d}" && [ -n "$flagPrefix" ] && vat_env="${flagPrefix}${vat_env}"
vat_exec="${VAT_EXEC_DIR:-/etc/vat/exec.d}" && [ -n "$flagPrefix" ] && vat_exec="${flagPrefix}${vat_exec}"

if $flagInit; then
  echo "source /etc/profile.d/vat-env" >> /etc/bash.bashrc
  mkdir -p "/etc/zsh" && echo "source /etc/profile.d/vat-env" >> /etc/zsh/zshrc
  mkdir -p "$VAT_ENV_DIR" "$VAT_EXE_DIR" /opt/vat/bin /opt/vat/sbin

  if [ -d "/etc/s6-overlay" ]; then
    mkdir -p "$s6env"
    copy -a "${VAT_ENV_DIR}/." "$s6env"
  fi

  exit 0
fi

if $flagExe; then
  echo "### START: EXECUTABLE HINTS ###"
  while [[ "$#" -gt 0 ]]; do
    val="$1"
    echo "  $val..."
    if ! echo "${excluded[*]}" | grep -wq "$val"; then
      for pattern in "${transform[@]}"; do
        val=$(sed "$pattern" <<< "$val")
      done
      vat-putexe <<< "$val"
    fi
    shift
  done
  echo "### END: ADDING EXECUTABLE HINTS ###"
  exit 0
fi

if $flagSet; then
  echo "### START ADDING ENVIRONMENT VARIABLES ###"
  while [[ "$#" -gt 0 ]]; do
    key=$(echo "$1" | cut -d '=' -f 1 | tr '[:lower:]' '[:upper:]')
    value="$(echo "$1" | cut -d '=' -f 2- | sed 's#\"##g')"
    vat-putenv "${key}" <<< "${value}"
    shift
  done
  echo "### END: ADDING ENVIRONMENT VARIABLES ###"
  exit 0
fi

if $flagFinish; then
  echo "### Start: COPYING PLUGIN FILES ###"
  cp -av /src/plugins/. /
  echo "### End: COPYING PLUGIN FILES ###"

  # Turn Executables into Environment Variables
  echo "### START: CREATING ENVIRONMENT ###"
  for file in "$VAT_EXE_DIR"/*; do
    exe=$(cat "$file")
    filename=$(basename "$file")
    resolved="$exe"
    if [ ! -f "$exe" ]; then
      resolved=$(try_which "$exe")
      if  [ -z "$resolved" ]; then
        echo "ERROR: Could not locate $i in the path or at any of these locations:"
        for t in "${try[@]}"; do
          echo "  ${t}/${i}"
        done
      fi
    fi

    echo "  $filename..."
    name=$(echo "$filename" | tr '[:lower:]' '[:upper:]' | sed 's#-##g')
    optPath="/opt/vat/bin/$filename"
    ln -s "${resolved}" "$optPath"
    vat-putenv "${name}_EXE" <<< "${optPath}"
  done
  echo "### END: CREATING ENVIRONMENT ###"

  if [ -d "/etc/s6-overlay/s6-rc.d" ]; then
    echo "### CORRECTING S6 PERMISSIONS ###"
    chmod 755 /etc/s6-overlay/s6-rc.d/*/run
    chmod 755 /etc/s6-overlay/s6-rc.d/*/data/check
  fi
fi

## endregion ######################################## Main Code

