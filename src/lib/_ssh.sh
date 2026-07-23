#!/usr/bin/env zsh

# shellcheck source=./_fs.sh
copy_sshconfig() {
  local config_path match raw isGlobal
  local dest_dir dest_path
  local include_path include_name line match
  local include_raw include_path include_name include_dest
  local key_raw key_path key_name key_dest
  local raw host

  dest_path="$1"
  if [[ ! -t 0 ]]; then
    config_path=$(cat)
  else
    config_path="$HOME/.ssh/config"
  fi

  # Check if the config file exists
  if [[ ! -f "$config_path" ]]; then
    echo "Error: SSH config file '$config_path' not found" >&2
    return 1
  fi

  # Create Output
  dest_dir=$(dirname "$(dirname "$config_path")")
  mkdir -p "$dest_dir"

  # Process file line by line
  while IFS= read -r line; do

    # Shortcut for empty lines
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      echo "$line" >> "$dest_path"
      continue
    fi

    # Handle Include directive
    if [[ "$line" =~ ^[[:space:]]*Include[[:space:]]+(.*)$ ]]; then
      include_raw="${match[1]}"
      include_path="$include_raw"
      include_name include_dest

      # Expand tilde if present
      if [[ "$include_path" == ~* ]]; then
        include_path="${include_path/#\~/$HOME}"
      fi

      # Handle relative paths
      if [[ "$include_path" != /* ]]; then
        include_path="${config_path%/*}/$include_path"
      fi

      include_name=$(basename "$include_path")

      # Copy included the path to secrets
      include_dest=$(fs::copy::unique "$include_path" "$dest_dir/$include_name")

      # Output to container config
      include_name=$(basename "$include_dest")
      echo "$line" | sed "s|$include_raw|/run/secrets/.ssh/$include_name|g" >> "$dest_path"

      # Process included the file recursively
      copy_sshconfig "$include_dest" <<< "$include_path"
      continue
    fi

    # Handle Host blocks
    if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.*)$ ]]; then
      raw="${match[1]}"

      # Strip any inline comments
      host="${raw%%#*}"

      if [[ "$host" == "*" ]]; then
        isGlobal=true
      else
        isGlobal=false
      fi

      # Output without changes
      echo "$line" >> "$dest_path"

      continue
    fi

    # Process key lines
    if [[ "$line" =~ ^[[:space:]]*IdentityFile[[:space:]]+(.*)$ ]]; then
      key_raw="${match[1]}"
      key_raw="${key_raw%%#*}"
      key_path="$key_raw"

      # Expand tilde if present
      if [[ "$key_path" == ~* ]]; then
        key_path="${$key_path/#\~/$HOME}"
      fi

      # Handle relative paths
      if [[ "$key_path" != /* ]]; then
        key_path="${config_path%/*}/$key_path"
      fi

      if $isGlobal; then
        # Just copy the key
        key_name=$(basename "$key_path")
        key_dest="$dest_dir/$key_name"
        rsync -av "$key_path" "$key_dest"
      else
        key_name=$(basename "$key_path")
        key_dest=$(fs::copy::unique "$key_path" "$dest_dir/$key_name")

        # Output to container config
        key_name=$(basename "$key_dest")
      fi

      echo "$line" | sed "s|$key_raw|/run/secrets/.ssh/$key_name|g" >> "$dest_path"

      continue
    fi
  done
}