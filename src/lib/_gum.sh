#!/usr/bin/env zsh -x
export CLICOLOR_FORCE=1
export GUM_BACKGROUND=dark

BLACK=0 &&
  RED=1 &&
  GREEN=2 &&
  YELLOW=3 &&
  BLUE=4 &&
  MAGENTA=5 &&
  CYAN=6 &&
  WHITE=7 &&
  HR="---------------------------------------------"

spin-bash() {
  local task task_title

  task="$1"

  # Header from stdin
  [[ ! -t 0 ]] && task_title=$(cat)

  if declare -f "$task" > /dev/null; then
      export -f "$task"
      shift
      gum spin --spinner dot --title "$task_title" "$@" -- bash -c "$task"
  else
      gum spin --spinner dot --title "$task_title" "$@"
  fi
}

spin-zsh() {
  local task task_title

  task="$1"

  # Header from stdin
  [[ ! -t 0 ]] && task_title=$(cat)

  if [[ "$(whence -w "$task" 2>/dev/null)" == "${task}: function" ]]; then
    local fn_definition="${functions[$task]}"
    shift
    gum spin "$@" -- zsh -c "function $task() { $fn_definition }; $task"
  else
    gum spin "$@"
  fi
}

# Quiet execution spinner with a badge and error dump on failure
spin() {
  local task_title result tmp_log

  # Header from stdin
  [[ ! -t 0 ]] && task_title=$(cat)
    
  # Create a unique temporary file for capturing logs
  tmp_log=$(mktemp)
  result=true

  if [ -n "$BASH_VERSION" ]; then
    if ! echo "$task_title" | spin-bash "$@" > "$tmp_log" 2>&1; then
      result=false
    fi
  elif [ -n "$ZSH_VERSION" ]; then
    if ! echo "$task_title" | spin-zsh "$@" > "$tmp_log" 2>&1; then
      result=false
    fi
  else
    return 1
  fi

  if $result; then
    symbol=$(gum style --foreground "$GREEN" "✓")
    echo "$symbol  $task_title"
    # printf "%-50s [%s]\n" "$task_title" "$(gum style --foreground 2 --bold "PASS")"
    rm -f "$tmp_log"
    return 0
  else
    # On Failure: Print the FAIL line
    symbol=$(gum style --foreground "$RED" "✗")
    echo "$symbol  $task_title"
    # printf "%-50s [%s]\n" "$task_title" "$(gum style --foreground 1 --bold "FAIL")"
    
    # Format and dump the suppressed error output
    if [[ ! -s "$tmp_log" ]]; then
      echo "" | gum format --theme="dark"
      gum style --foreground 1 --bold "─── ERROR OUTPUT ───"
      cat "$tmp_log"
      gum style --foreground 1 --bold "────────────────────"
      echo ""
    fi
    
    rm -f "$tmp_log"
    return 1
  fi
}

# Wrapper functions for charmbraclet/gum
# Each function reads title/header from stdin and accepts additional arguments

# gum_choose wraps gum choose
# Usage: echo "Title" | gum_choose --limit 1 --height 20 --placeholder "Select..."
choose() {
  local title

  # Header from stdin
  [[ ! -t 0 ]] && title=$(cat)

  if [[ -z "$title" ]]; then
    gum choose "$@"
  else
    gum choose --header "$title" "$@"
  fi
}

# Wrapper functions for charmbraclet/gum
# Each function reads title/header from stdin and accepts additional arguments

# gum_choose wraps gum choose
# Usage: echo "Title" | gum_choose --limit 1 --height 20 --placeholder "Select..."
choose-filter() {
  local title

  # Header from stdin
  [[ ! -t 0 ]] && title=$(cat)

  if [[ -z "$title" ]]; then
    gum filter "$@"
  else
    gum filter --header "$title" "$@"
  fi
}

# gum_file wraps gum file
# Usage: echo "Title" | gum_file --height 20 --placeholder "Select file..."
choose-file() {
  local title

  # Header from stdin
  [[ ! -t 0 ]] && title=$(cat)
  
  if [[ -z "$title" ]]; then
    gum file "$@"
  else
    gum file --header "$title" "$@"
  fi
}

# gum_input wraps gum input
# Usage: echo "Title" | gum_input --placeholder "Enter value..." --value "default"
ask() {
  local title default

  default="$1"

  # Header from stdin
  [[ ! -t 0 ]] && title=$(cat)
  
  if [[ -z "$title" ]]; then
    echo "$default" | gum input "$@"
  else
    echo "$default" | gum input --header "$title" "$@"
  fi
}

# gum_confirm wraps gum confirm
# Usage: echo "Title" | gum_confirm --default true
yn() {
  local title

  # Header from stdin
  [[ ! -t 0 ]] && title=$(cat)
  
  if [[ -z "$title" ]]; then
    gum confirm "$@"
  else
    gum confirm --no-show-help "$title" "$@"
  fi
}

function normalize_color() {
  local myFg

  myFg="$1"

  if [[ -n "$myFg" && ! "$myFg" =~ ^# && "$myFg" =~ [^0-9] ]]; then
    case "$myFg" in 
      false | red | error | fail | ERROR | FAIL )                      myFg="$RED" ;;
      true | green | success | pass | done | SUCCESS | PASS | DONE )  myFg="$GREEN" ;;
      yellow | warn | WARN )                                   myFg="$YELLOW" ;;
      blue )                                                   myFg="$BLUE" ;;
      magenta | msg )                                          myFg="$MAGENTA" ;;
      cyan | info )                                            myFg="$CYAN" ;;
      white )                                                  myFg="$WHITE" ;;
      *)                                                       myFg="" ;;
    esac
  fi

  echo "$myFg"
}

SPINNER_PID=""
SPINNER_TEXT=""

# Helper function to clear previous spinner frames cleanly
clear_spinner() {
  printf "\r\033[K"
}

# The customized notification filter (intercepts text to trigger spinner)
notify() {
  local input
  [[ ! -t 0 ]] && input=$(cat)

  # Clear any legacy line artifacts
  clear_spinner

  # Safely start the gum spin process globally
  SPINNER_TEXT="$input"
  if ! $flagQ; then
    gum spin --title "$input" -- sleep 100000 &
    SPINNER_PID=$!
  else
    echo "(Start) $input" | log
  fi
}

bg() {
  local myFg
  myFg=$(normalize_color "$1")

  # Ensure the spinner is fully terminated and cleaned up first
  if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
    kill "$SPINNER_PID"
    wait "$SPINNER_PID" 2>/dev/null
  fi
  tput cnorm
  clear_spinner

  if ! $flagQ; then
    if $1; then
      # SUCCESS: Green Checkmark
      CHECKMARK=$(gum style --foreground "$GREEN" "✓")
      echo "$CHECKMARK  $SPINNER_TEXT"
    else
      # FAILURE: Red X
      CROSS=$(gum style --foreground "$RED" "✗")
      echo "$CROSS  $SPINNER_TEXT"
    fi
  else 
    echo "($status_text) $SPINNER_TEXT" | log
  fi
  stty echo
}

# The customized status layout filter
badge() {
  local status_text myFg myBg
  read -r status_text

  myFg="$1"
  myBg="$2"

  if [[ -z "$myFg" ]]; then
    myFg=$(normalize_color "$status_text")
  else
    myFg=$(normalize_color "$myFg")
  fi
  
  # Ensure the spinner is fully terminated and cleaned up first
  if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
    kill "$SPINNER_PID"
    wait "$SPINNER_PID" 2>/dev/null
  fi
  tput cnorm
  clear_spinner

  # Format output depending on success or failure status strings
  if ! $flagQ; then
    echo "  [$(gum style --foreground "$myFg" "$status_text")] $SPINNER_TEXT"
  else 
    echo "($status_text) $SPINNER_TEXT" | log
  fi
}

function out() {
  local line myFg myBg

  myFg="$1"
  myBg="$2"
  myFg=$(normalize_color "$myFg")
  myBg=$(normalize_color "$myBg")

  if $flagQ; then
    while IFS= read -r line; do
      echo "$line" | log
    done
  else
    while IFS= read -r line; do
      gum style --foreground "$myFg" "$line"
    done
  fi
}
