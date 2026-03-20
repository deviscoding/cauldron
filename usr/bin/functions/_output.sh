#!/bin/bash

# Horizonal Rules are Cool
HR="---------------------------------------------"
outNotifying=false
isQuiet=false

# Terminal Colors
if [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
  colorRed=$(/usr/bin/tput setaf 1) #"\033[1;31m"
  colorBlue=$(/usr/bin/tput setaf 4) #"\033[1;36m"
  colorGreen=$(/usr/bin/tput setaf 2) #"\033[1;32m"
  colorYellow=$(/usr/bin/tput setaf 3) #"\033[1;33m"
  colorEnd=$(/usr/bin/tput sgr0) #"\033[0m"
else
  colorRed="" && colorBlue="" && colorEnd="" && colorYellow=""
fi

# @description Ask a yes/no question and return a boolean answer.
# @arg $1 string The yes/no Question
# @stdout string The question, printed in blue
# @exitcode 0 Yes
# @exitcode 1 No
function ask() {
  local reply

  echo -e -n "${colorYellow}$1${colorEnd} [y/n] "
  read -r reply </dev/tty
  case "$reply" in
  Y*|y*) return 0 ;;
  N*|n*) return 1 ;;
  esac
}

function out-notify() {
  local padding="---------------------------------------------------------------------------"
  outNotifying=true
  ! $isQuiet && printf "${colorBlue}%s${colorEnd}%s " "$1" "${padding:${#1}}"
}

function badge() {
  local BADGE colorThis
  colorThis="$1"
  BADGE=${2}
  ! $isQuiet && $outNotifying && echo -e "[${colorThis}$BADGE${colorEnd}]"
  outNotifying=false

  return 0
}

function badge-success() {
  badge "$colorGreen" "$1"
}

function badge-error() {
  badge "$colorRed" "$1"
}

function err {
  local line
  while IFS= read -r line; do >&2 echo "${colorRed}$line${colorEnd}"; done
}

# @description Outputs question text in yellow, and waits for the user to type a reply
# followed by the enter key.
#
#   Example:
#     response=$(output::question::text "What is your quest?")
#
# @arg $1 string The question
# @arg $2 string The default answer
# @stdout string The response
function ask-text() {
  local ANSWER
  local QUESTION
  local DEFAULT

  DEFAULT="$2"
  QUESTION="${colorYellow}$1${colorEnd} ${DEFAULT:+ [$DEFAULT]}"

  read -r -ep "$QUESTION: " ANSWER </dev/tty || return 1

  echo "${ANSWER:-$DEFAULT}"
  return 0
}