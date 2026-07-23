#!/usr/bin/env zsh

# @arg $1 string The question
# @arg $2 string The default answer
# @stdout string The response
function ask() {
  local reply quest default

  if [[ ! -t 0 ]]; then
    quest="$(cat)"
    default="$1"
    quest="${YELLOW}${quest}${RESET} ${default:+ [$default]}"

    read -r -ep "$quest: " reply </dev/tty || return 1
    echo "${reply:-$default}"
    return 0
  fi

  return 2
}

function choice() {
  local quest default in

  if [[ ! -t 0 ]]; then
    in="$(cat)"
    quest=$(echo "$in" | awk -F'|' '{print $1}')
    default=$(echo "$in" | awk -F'|' '{print $2}')
  fi

  while [[ -n "$1" ]]; do
    if echo "$1" | jq empty 2>/dev/null; then
      # JSON - Loop through each object .choice and .label
      for choice in $(echo "$1" | jq -r '.choices[] | @base64'); do
        _jq() { echo "${choice}" | base64 --decode | jq -r "${1}"; }
        label=$(_jq '.label')
        value=$(_jq '.value')
        echo "${WHITE}${label}${RESET} ) ${CYAN}${value}${RESET}"
      done
    else
      choice=$(echo "$1" | awk -F'|' '{print $1}')
      label=$(echo "$1" | awk -F'|' '{print $2}')
      echo "${WHITE}$choice${RESET} ) ${CYAN}$label${RESET}"
    fi
    shift
  done
  echo ""

  # Display title if provided
  if [[ -n "$title" ]]; then
    echo "${YELLOW}$title${RESET}"
    echo ""
  fi

  read -r -ep "$quest: " reply </dev/tty || return 1
  echo "${reply:-$default}"
  return 0
}

# @description Ask a yes/no question and return a boolean answer.
# @stdout string The question, printed in yellow
# @stdin  string Question to Ask
# @exitcode 0 Yes
# @exitcode 1 No
function yn() {
  local reply quest

  if [ ! -t 0 ]; then
    quest="$(cat)"
    echo -e -n "${YELLOW}$quest${RESET} [y/n] "
    read -k1 reply </dev/tty
    echo ""
    case "$reply" in
    Y* | y* ) return 0 ;;
    N* | n* ) return 1 ;;
    $'\e')
      read -rsn2 -t 0.001 next_chars </dev/tty
      [[ -z "$next" ]] && return 1
      ;;
    *)      [[ -z "$reply" ]] && return 0 ;;
    esac
  else
    return 2
  fi
}