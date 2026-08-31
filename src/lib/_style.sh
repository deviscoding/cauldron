#!/usr/bin/env zsh

SPINNER_PID=""

## region ############################################## Variable Declarations

# shellcheck disable=SC2034
if [[ -z "$HR" ]]; then
  if [[ -n "$NO_COLOR" || "$TERM" =~ ^(dumb|emacs)$ || -n "$CI" ]] || ! command -v tput > /dev/null 2>&1; then
    RED="" && GREEN="" && YELLOW="" && BLUE="" && MAGENTA="" && CYAN="" && WHITE="" && RESET=""
  else
    RED=$(tput setaf 1) \
      && GREEN=$(tput setaf 2) \
      && YELLOW=$(tput setaf 3) \
      && BLUE=$(tput setaf 4) \
      && MAGENTA=$(tput setaf 5) \
      && CYAN=$(tput setaf 6) \
      && WHITE=$(tput setaf 7) \
      && RESET=$(tput sgr0)
  fi
  CHECK="${GREEN}✓${RESET}"
  CROSS="${RED}✗${RESET}"
  FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  HR="---------------------------------------------"
fi

# shellcheck disable=SC2034
declare -r RED GREEN YELLOW BLUE MAGENTA CYAN WHITE RESET CHECK CROSS FRAMES HR

## endregion ########################################### Variable Declarations

## region ############################################## Internal Functions

function _spinner() {
  printf "\r\e[K${MAGENTA}%-1s${RESET} %s" "$1" "$2"
}

function _clear() {
  # If the spinner process exists, terminate it cleanly
  if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2> /dev/null; then
    kill "$SPINNER_PID" 2> /dev/null
    wait "$SPINNER_PID" 2> /dev/null
  fi
  tput el    # Clear the lingering spinner frame from the screen
  tput cnorm # Make sure the terminal cursor is restored
}

function _check() {
  printf "\r\e[K${GREEN}%-1s${RESET} %s\n" "✓" "$1"
}

function _done() {
  printf "\r\e[K${WHITE}%-1s${RESET} %s\n" "✓" "$1"
}

function _cross() {
  printf "\r\e[K${RED}%-1s${RESET} %s\n" "✗" "$1"
}

function _down() {
  printf "\r\e[K${WHITE}%-1s${RESET} %s\n" "↓" "$1"
}

function _up() {
  printf "\r\e[K${WHITE}%-1s${RESET} %s\n" "↑" "$1"
}

function _status() {
  local text stat
  if [[ ! -t 0 ]]; then
    text="$(cat)"
  fi
  stat="$1"

  if [[ -z "$status" ]]; then
    _up "$text"
  elif [[ "$stat" -eq 0 ]]; then
    _check "$text"
  else
    _cross "$text"
  fi
}

_clear() {
  # CRITICAL: We must find and kill the subshell AND its active sleep command
  if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2> /dev/null; then
    # Find the sleep child of the spinner process and kill it to prevent hanging
    local child_pid=$(pgrep -P "$SPINNER_PID" 2> /dev/null)
    [[ -n "$child_pid" ]] && kill "$child_pid" 2> /dev/null

    kill "$SPINNER_PID" 2> /dev/null
    wait "$SPINNER_PID" 2> /dev/null
  fi
  printf "\r"
  tput el    # Clear the lingering spinner frame
  tput cnorm # Restore the terminal cursor
}

cleanup() {
  echo "DEBUG: Trap triggered!" >&2 # Force print to stderr
  _clear
  exit 130 # 130 is the standard exit code for Ctrl+C
}

# Catch Ctrl+C (INT) and normal script exits (TERM)
TRAPINT() {
  _clear
  return 130
}

TRAPTERM() {
  _clear
  return 143
}

## endregion ########################################### Internal Functions

## region ############################################## Logging Functions

function log() {
  local line

  if [[ -n "$selfLog" && -n "$selfDate" ]]; then
    while IFS= read -r line; do echo "[$selfDate] $line" >> "$selfLog"; done
  fi
}

## endregion ########################################### Internal Functions

## region ############################################## Output Functions

# @brief Outputs text in the given color
# @arg $1 string Color to use for output
# shellcheck disable=SC2329
function out-red() {
  out "$RED" <<< "$(cat)"
}

# shellcheck disable=SC2329
function out-success() {
  out "$GREEN" <<< "$(cat)"
}

function normalize_color() {
  local myFg

  myFg="$1"

  if [[ -n "$myFg" && ! "$myFg" =~ ^# && "$myFg" =~ [^0-9] ]]; then
    case "$myFg" in
    false | red | error | fail | ERROR | FAIL) myFg="$RED" ;;
    true | green | success | pass | done | SUCCESS | PASS | DONE) myFg="$GREEN" ;;
    yellow | warn | WARN) myFg="$YELLOW" ;;
    blue) myFg="$BLUE" ;;
    magenta | msg) myFg="$MAGENTA" ;;
    cyan | info) myFg="$CYAN" ;;
    white) myFg="$WHITE" ;;
    *) myFg="" ;;
    esac
  fi

  echo "$myFg"
}

# @brief Outputs text in the given context color
# @arg $1 string Context
# @stdin  string Lines to Output
# @stdout string Output Lines in context color
function out() {
  local line pre suf

  # Kill the background spinner process cleanly
  kill "$SPINNER_PID" 2> /dev/null
  wait "$SPINNER_PID" 2> /dev/null

  pre=$(normalize_color "$1")
  [[ -n "$pre" ]] && suf="$RESET"
  if $flagQ; then
    while IFS= read -r line; do
      echo "$line" | log
    done
  else
    while IFS= read -r line; do
      printf "%s%s%s\n" "$pre" "$line" "$suf"
    done
  fi
}

table() {
  local json_input=""
  local headers=()
  local -a data_rows=()

  # Parse arguments to get JSON input
  if [[ ! -t 0 ]]; then
    json_input="$(cat)"
  fi

  # Validate JSON input
  if [[ -z "$json_input" ]]; then
    echo "Error: No JSON input provided" >&2
    return 1
  fi

  # Check if jq is available
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    return 1
  fi

  jq -r '(.[0] | keys_unsorted | join("\t│\t")), (.[] | map(. // "") | join("\t│\t"))' <<< "$json_input" | column -t -s $'\t' | awk 'NR==2 {dashes=$0; gsub(/[^│]/, "─", dashes); gsub(/│/, "┼", dashes); print dashes} 1'
}

## endregion ########################################### Internal Functions

## region ############################################## Spinner Functions

function spin() {
  local text="Loading"

  # Kill the background spinner process cleanly
  _clear

  if [[ ! -t 0 ]]; then
    text="$(cat)"
    SPINNER_TEXT="$text"
  fi

  # Hide the terminal cursor
  tput civis

  # Define your exact 10-frame animation sequence
  local frame_count=${#FRAMES[@]}

  # Run the spinner loop in the background
  (
    local i=0
    local delay=0.1
    while true; do
      # CRITICAL SELF-DESTRUCT: If the parent script dies suddenly from a
      # blocked Ctrl+C, the spinner notices instantly and cleans up the terminal.
      if ! kill -0 "$PARENT_PID" 2> /dev/null; then
        printf "\r"
        tput el
        tput cnorm
        exit 0
      fi

      local frame="${FRAMES[i]}"
      printf "\r\e[K${MAGENTA}%-1s${RESET} %s" "$frame" "$text"
      i=$(((i + 1) % frame_count))
      sleep $delay
    done
  ) &

  # Save the background process ID (PID)
  SPINNER_PID=$!
}

function finish() {
  local stat
  local text="$SPINNER_TEXT"

  stat="$1"
  SPINNER_TEXT=""
  if $stat; then
    stat=0
  else
    stat=1
  fi

  # Kill the background spinner process cleanly
  _clear

  # Overwrite the line with the final status and text
  sleep 0.1
  _status "$stat" <<< "$text"
}

function cronic() {
  local stat=0
  # Parse arguments manually
  local title="Loading..."
  local hr="---------------------------------------------"

  if [[ ! -t 0 ]]; then
    title="$(cat)"
  fi

  local tmp_log
  tmp_log=$(mktemp)

  # Create a unique temporary file for capturing logs
  tmp_log=$(mktemp)
  result=true

  # Run the target command in the background
  # "$@" contains the rest of the arguments after the '--' split
  if ! $flagV; then

    "$@" > "$tmp_log" 2>&1 &
    pid=$!

    # Hide the terminal cursor so it looks clean
    tput civis

    # Loop animation frame-by-frame while process is running
    while kill -0 "$pid" 2> /dev/null; do
      for frame in "${FRAMES[@]}"; do
        # Check one more time inside the frame loop to prevent lag on exit
        if ! kill -0 "$pid" 2> /dev/null; then break; fi

        # Print frame + title (\r resets the line, \e[K clears to the end)
        # _spinner "$frame" "$title"
        printf "\r\e[K\e[35m%s\e[0m %s" "$frame" "$title"
        sleep 0.1
      done
    done

    # Clean up: bring the cursor back and print a newline
    tput cnorm
    ! $flagQ && printf "\r\e[K"

    # Inherit and return the original process's exit code
    wait "$pid"
    stat=$?

    # shellcheck disable=SC2181
    if [[ "$stat" -eq "0" ]]; then
      ! $flagQ && _check "$title"
    elif ! $flagQ; then
      _cross "$title"
      >&2 echo $hr
      cat "$tmp_log" >&2
      >&2 echo $hr
    fi
  elif ! $flagQ; then
    echo $hr
    "$@"
    stat=$?
    echo $hr
    _status "$stat" <<< "$title"
  else
    "$@" > /dev/null 2>&1
    stat=$?
  fi

  echo "(Start) $title" | log
  cat "$tmp_log" | log
  echo "(End) $title" | log

  # Clean up
  [[ -f "$tmp_log" ]] && rm "$tmp_log"

  return $stat
}
