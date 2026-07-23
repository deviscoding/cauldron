#!/bin/bash

function out::version() {
  if $flagQ; then
    echo "$selfVer"
  else
    echo "$selfName v$selfVer"
    [[ -n "$selfRepo" ]] && echo "($selfRepo)"
  fi
}

function out::help() {
  if [[ -z "$selfUsage" ]] && ! $flagQ; then
    out::version
  elif ! $flagQ; then
    echo "$selfUsage"
  fi
}


function in::type() {
  case "$1" in
  *+) echo "+" ;;
  *:) echo ":" ;;
  *)  echo "=" ;;
  esac

  return 0
}

function in::var() {
  local sfx typ

  typ=$(in::type "$1")
  sfx="$(echo "${1:0:1}" | tr '[:lower:]' '[:upper:]')${1:1}"

  case "$typ" in
    + | :) echo "flag${sfx%?}" ;;
    *)     echo "flag${sfx}";  ;;
  esac

  return 0
}

function in::isFlag() {
  local flag
  for flag in "${selfFlags[@]}"; do
    if [[ "$flag" =~ "${flag}"[:|+]$ ]]; then
      return 0
    fi
  done
  return 1
}

function in::finalize() {
  local v flag

  for flag in "${selfFlags[@]}"; do
    v=$(in::var "$flag")
    case "$flag" in
      quiet | verbose | help | q | h ) ;;
      *) readonly "$v" ;;
    esac
  done
}

if typeset -f "_initialize" > /dev/null; then
  _initialize
fi

[[ -z "$selfVer"  ]] && selfVer=x.x.x
[[ -z "$selfName" ]] && selfName=$(basename "${BASH_SOURCE[0]}")
! declare -p selfFlags &>/dev/null && declare selfFlags=()
readonly selfVer selfName selfUsage selfFlags

read -r flagQ flagV flagH flagVer <<< "false false false false"
in=()
while [[ "$1" != "" ]]; do
  case "$1" in
  -q | --quiet )   flagQ=true;     ;;
  -v | --verbose ) flagV=true;     ;;
  -h | --help )    flagH=true;     ;;
  --version )      flagVer=true;   ;;
  *)               in+=("$1")      ;;
  esac
  shift
done
readonly flagQ flagV flagH flagVer
set -- "${in[@]}"

if [ ${#selfFlags[@]} -gt 0 ]; then
  for flag in "${selfFlags[@]}"; do
    var=$(in::var "$flag")
    typ=$(in::type "$flag")

    case "$flag" in
      quiet | verbose | help | version | q | h ) ;;
      *+) flag="${flag%?}"; declare -a "$var";          ;;
      *:) flag="${flag%?}"; printf -v "$var" "%s" "";   ;;
      *) printf -v "$var" "%s" false;                  ;;
    esac

    in=()
    while [[ "$1" != "" ]]; do
      if [[ "${1}" == "--$flag" ]]; then
        case "$typ" in
          +) val="$2"; ! in::isFlag "$val" && shift && eval "${var}+=('$val')"; ;;
          :) val="$2"; ! in::isFlag "$val" && shift && printf -v "$var" "%s" "$val" ;;
          *) val="true"; printf -v "$var" "%s" "$val" ;;
        esac
      else
        in+=("$1")
      fi
      shift
    done
    set -- "${in[@]}"
  done
fi

if $flagVer; then
  out::version
  exit 0
elif $flagH; then
  out::help
  exit 0
fi
