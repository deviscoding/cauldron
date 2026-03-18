#!/bin/bash

## endregion ######################################## Functions

## region ########################################### Variables

profileD="/etc/profile.d"
try=("/usr/local/bin" "/usr/bin")
label="apache"
exes=()
vars=()

## endregion ######################################## Variables

## region ########################################### Functions

# @description echos STDIN to the log file, prefixing each line with a datestamp; used via pipe
# @stdin string KEY=value environment variable pair
# @noargs
function xport() {
  local line key value name

  while IFS= read -r line; do
    key=$(echo "$line" | awk -F'=' '{ print $1 }')
    value=$(echo "$line" | awk -F'=' '{ print $2 }')
    name=$(echo "$key" | awk -F'_' '{ print $1 }' |  awk '{print tolower($0)}')
    [ -z "$profileFile" ] && profileFile="${profileD}/${label}-${name}.sh"
    if [ ! -f "$profileFile" ]; then
      echo "#!/bin/bash" > "$profileFile"
      echo "" >> "$profileFile"
      chmod 755 "$profileFile"
    fi
    echo "export $line" | sed -ri 's/^export ([^=]+)=(.*)$/export \1=${\1:-\2}/' >> "$profileFile"
  done
}

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

## endregion ######################################## Functions

## region ########################################### Main Code

#
# Input Handling
#
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --set)       vars+=("$2"); shift ;;
  --prefix)    prefix="$1"; shift ;;
  --name)      profileN="$2"; shift ;;
  *)           exes+=("$1")
  esac
  shift
done

#
# Handle Prefix & Profile Name
#
if [ -n "$prefix" ]; then
  profileD="$prefix/$profileD"
fi

if [ -n "$profileN" ]; then
  profileFile="$profileD/${label}-${profileN}.sh"
fi

#
# Make sure the necessary files exist
#
[ ! -d "$profileD" ] && \
  mkdir -p "$profileD"

# Loop through executables, find them, and add paths to /etc/profile.d and /etc/apache2/conf-available to allow
# access from both CLI and Apache-served apps
for i in "${exes[@]}"
do
  if iPath=$(try_which "$i"); then
    suffix="EXE"
    name=$(echo "$i" | tr '[:lower:]' '[:upper:]')
    echo "${name}_${suffix}=${iPath}" | xport
  else
    echo "ERROR: Could not locate $i in the path or at any of these locations:"
    for t in "${try[@]}"; do
      echo "    ${t}/${i}"
    done
    exit 1
  fi
done

# Add any vars
for v in "${vars[@]}"
do
  echo "$v" | xport
done
exit 0

## endregion ######################################## Main Code

