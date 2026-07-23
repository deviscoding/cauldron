#!/usr/bin/env zsh

blockinfile() {
  local label="$1"
  local target="$2"

  if [[ -z "$label" || -z "$target" ]]; then
    echo "Usage: blockinfile <label> <target_file>" >&2
    return 1
  fi

  local start_m="# BEGIN $label"
  local end_m="# END $label"

  local tmp_input=$(mktemp)
  local tmp_block=$(mktemp)
  local tmp_out=$(mktemp)

  # Capture stdin
  cat > "$tmp_input"

  local file_exists=false
  [[ -s "$target" ]] && file_exists=true

  # 1. Prepare the block payload
  if [ "$file_exists" = true ]; then
    {
      echo "$start_m"
      sed '1{/^#!/d}' "$tmp_input"
      echo "$end_m"
    } > "$tmp_block"
  else
    touch "$target"
    if head -n 1 "$tmp_input" | grep -q "^#!"; then
      head -n 1 "$tmp_input" > "$tmp_block"
      echo "$start_m" >> "$tmp_block"
      sed '1d' "$tmp_input" >> "$tmp_block"
      echo "$end_m" >> "$tmp_block"
    else
      { echo "$start_m"; cat "$tmp_input"; echo "$end_m"; } > "$tmp_block"
    fi
  fi

  # 2. Apply the block safely
  if grep -qF "$start_m" "$target"; then
    # Safely swap the old block using awk
    awk -v start="$start_m" -v end="$end_m" -v block_file="$tmp_block" '
      $0 == start {
        # Print the new block content once
        while ((getline line < block_file) > 0) { print line }
        close(block_file)
        skip = 1
        next
      }
      $0 == end {
        skip = 0
        next
      }
      !skip { print }
    ' "$target" > "$tmp_out"
    mv "$tmp_out" "$target"
  elif [ "$file_exists" = true ]; then
    # Append to an existing file with a clean newline separator
    echo "" >> "$target"
    cat "$tmp_block" >> "$target"
  else
    # Brand-new file
    cat "$tmp_block" > "$target"
  fi

  rm -f "$tmp_input" "$tmp_block" "$tmp_out"
}
