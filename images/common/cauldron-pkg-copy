#!/bin/bash

pkg="$1"
dest="$2"
files=$(dpkg-query -L "$pkg")
echo "$files"
while IFS= read -r line; do
  if [ -f "$line" ]; then
    parent=$(dirname "$line")
    parent="$dest${parent}"
    printf "Copying '%s' to '%s'" "$line" "$parent"
    [ ! -d "$parent" ] && mkdir -p "$parent"
    if cp "$line" "$parent"; then
      echo "[DONE]"
    fi
  fi
done <<< "$files"
