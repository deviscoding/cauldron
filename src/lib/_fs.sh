#!/usr/bin/env zsh

# @brief Changes ownership of the given file or directory
# @flag -R       Recursive Ownership Assignment
# @arg $1 string Owner or Owner:Group; Group will be looked up if not included
# @arg $2 string File or Directory
# @exitcode 0 Success
# @exitcode 1 Error
function fs::chown() {
  local u g t args flags

  args=()
  flags=()
  while [[ "$1" != "" ]]; do
    case "$1" in
    -* )   flags+=("$1");  ;;
    *)     args+=("$1")    ;;
    esac
    shift
  done
  flags+=(" ")
  set -- "${args[@]}"

  u="$1"
  t="$2"

  if [[ -e "$t" && -n "$u" ]]; then
    if [[ ! "$u" == *":"* ]]; then
      g=$(id -g "$u")
      if [[ -n "$g" ]]; then
        u="$u:$g"
      fi
    fi
  else
    return 1
  fi

  chown "${flags[@]}" "$u" "$t" || return 1
}

fs::copy::unique() {
  local source destination_dir dest_path filename unique_path counter

  source="$1"
  destination_dir="$2"

  # Check if the source file exists
  if [[ ! -e "$source" ]]; then
    echo "Error: Source file '$source' does not exist" >&2
    return 1
  fi

  # Check if the destination directory exists
  if [[ ! -d "$destination_dir" ]]; then
    echo "Error: Destination directory '$destination_dir' does not exist" >&2
    return 1
  fi

  # Get the base filename
  filename=$(basename "$source")

  # Create the initial destination path
  dest_path="$destination_dir/$filename"

  # Generate a unique filename if needed
  counter=1
  unique_path="$dest_path"

  while [[ -e "$unique_path" ]]; do
    # Split filename and extension
    local name="${filename%.*}"
    local ext="${filename##*.}"

    # If there's no extension, just append the counter
    if [[ "$name" == "$filename" ]]; then
      unique_path="$destination_dir/${filename}_${counter}"
    else
      # If there's an extension, insert the counter before extension
      unique_path="$destination_dir/${name}_${counter}.${ext}"
    fi

    ((counter++))
  done

  # Use rsync to copy the file with preserved permissions and ownership
  # -a: archive mode (preserves permissions, ownership, timestamps, etc.)
  if rsync -av "$source" "$unique_path"; then
    echo "$unique_path"
    return 0
  else
    return 1
  fi
}