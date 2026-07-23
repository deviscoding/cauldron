#!/bin/bash

# Terminal cs
myLogDate=$(/bin/date "+%Y-%m-%d %H:%M:%S")
myLog="/tmp/log.log"
hr="-----------------------------------------------------------------------"

# Tracking File
out_v=$(mktemp)
echo "notify='false'" > "$out_v"
echo "context=''" > "$out_v"
# shellcheck disable=SC2064
trap "rm -f '$out_v'" EXIT

# shellcheck disable=SC2034
if [[ -n "$NO_COLOR" || "$TERM" =~ ^(dumb|emacs)$ || -n "$CI" ]] || ! command -v tput >/dev/null 2>&1; then
  RED="" && GREEN="" && YELLOW="" && BLUE="" && MAGENTA="" && CYAN="" && WHITE="" && RESET=""
else
  RED=$(tput setaf 1) &&
    GREEN=$(tput setaf 2) &&
    YELLOW=$(tput setaf 3) &&
    BLUE=$(tput setaf 4) &&
    MAGENTA=$(tput setaf 5) &&
    CYAN=$(tput setaf 6) &&
    WHITE=$(tput setaf 7) &&
    RESET=$(tput sgr0)
fi
# shellcheck disable=SC2034
declare -r RED GREEN YELLOW BLUE MAGENTA CYAN WHITE RESET

function state_read() {
  local key="$1"
  local def="${2}"

  # inline skip
  # shellcheck source=./.ignore
  source "$out_v" || return 1
  if [ -n "${!key}" ]; then
    echo "${!key}"
    return 0
  elif [ -n "$def" ]; then
    echo "$def"
    return 0
  fi

  return 1
}

function state_write() {
  local key="$1"
  local val="$2"
  local tmp_file="${out_v}.tmp"

  grep -v "^${key}=" "$out_v" > "$tmp_file" 2>/dev/null
  echo "$key='$val'" >> "$tmp_file"
  mv "$tmp_file" "$out_v"
}

function notify() {
  local line
  local padding="--------------------------------------------------------------------------"

  state_write "notify" "true"
  lines=$(cat)
  while IFS= read -r line; do
    if $flagV; then
      echo "$line"
    elif ! $flagQ; then
      printf "${BLUE}%s${RESET} %s " "$line" "${padding:${#line}}"
    fi
    echo "Trying: $line" | log
  done <<< "$lines"
}

function hr() {
  local line
  line="$1"
  indent=${2:-0}
  [ -n "$line" ] && line=" $line "
  printf "%s--%s%s\n" "$indent" "$1" "${hr:${#line}}"
}

function success() {
  state_write "context" "$GREEN"
  cat
}

function error() {
  state_write "context" "$RED"
  cat
}

function default() {
  state_write "context" "$WHITE"
  cat
}

function badge() {
  local myContext isNotify lines
  lines=$(cat)

  myContext="$(state_read "context")"
  isNotify=$(state_read "notify" "false")

  while IFS= read -r line; do
    if $isNotify; then
      ! $flagQ && printf "[%s%s%s]\n" "$myContext" "$line" "$RESET"
    fi
  done <<< "$lines"
  state_write notify false
  state_write context ""
  return 0
}

function out() {
  local line myContext
  if $flagQ; then
    while IFS= read -r line; do
      echo "$line" | log
    done
  else
    while IFS= read -r line; do
      myContext="$(state_read "context")"
      printf "%s%s%s\n" "$myContext" "$line" "$RESET"
    done
  fi
  state_write "context" ""
}

function verbose() {
  local line myContext
  myContext=$(state_read "context")
  if $flagV; then
    while IFS= read -r line; do
      echo "${myContext}$line${RESET}"
    done
  else
    while IFS= read -r line; do
      echo "$line" | log
    done
  fi
  state_write "context" ""
}

function log() {
  local line
  while IFS= read -r line; do echo "[$myLogDate] $line" >> "$myLog"; done
}

function _isChmodMode() {
  local mode="$1"
  case "$mode" in
  '') return 1 ;;
  [0-7]*) return 0 ;;  # Octal
  [ugoa+/-=*]*)
    case "$mode" in
    *[rwxXstTlP]*) return 0 ;;  # Symbolic allowed
    *) return 1 ;;              # Invalid chars
    esac
    ;;
  *) return 1 ;;  # Invalid format
  esac
}

dump() {
  local isUI mode args out isStrip

  args=()
  isUI=false
  isStrip=false
  while [[ "$1" != "" ]]; do
    case "$1" in
    --mode )   mode="$2"; shift   ;;
    --strip )  isStrip=true;      ;;
    *)         args+=("$1")       ;;
    esac
    shift
  done
  set -- "${args[@]}"
  out="$1"
  msg="$2"
  [[ -n "$msg" ]] && isUI=true

  $isUI && echo "$msg" | notify
  if [ ! -t 0 ]; then
    if $isStrip; then
      cat | perl -pe 'chomp if eof' > "$out"
    else
      cat > "$out"
    fi

    if [[ ! -f "$out" ]]; then
      $isUI && echo "ERROR" | error | badge
      return 1
    fi

    if [[ -n "$mode" ]]; then
      if ! chmod "$mode" "$out"; then
        $isUI && echo "ERROR" | error | badge
        return 1
      fi
    fi

    echo "DONE" | success | badge
  fi

  $isUI && echo "ERROR" | error | badge
  return 1
}

function cronic() {
  local tmp status isNotify
  tmp=$(mktemp)

  isNotify=$(state_read notify false)
  if ! $flagV; then
    # Run the command and redirect everything to a temp file
    "$@" > "$tmp" 2>&1
    status=$?

    # Only print the file content if the command failed
    if [ "$status" -ne 0 ]; then
      $isNotify && ! $flagQ && echo "ERROR" | error | badge
      ! $flagV && ! $flagQ && echo "$HR"
      ! $flagQ && cat "$tmp"
      ! $flagV && ! $flagQ && echo "$HR"
    fi

    rm -f "$tmp"
  else
    echo "$HR"
    "$@"
    status=$?
    echo "$HR"
  fi

  return "$status"
}
