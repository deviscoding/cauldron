if [ -z "$__ENV_LOADED" ]; then
  envDir="${VAT_ENV_DIR}"
  if [ -d /var/run/s6/container_environment ]; then
    envDir="/var/run/s6/container_environment"
  else
    envDir="${VAT_ENV_DIR}"
  fi

  if [ -d "$envDir" ]; then
    for file in "$envDir"/*; do
      # Ensure it is a valid, readable file
      if [ -f "$file" ]; then
        var_name=$(basename "$file")

        # Skip internal s6-overlay variables or filenames containing an '='
        case "$var_name" in
        S6_*|JUSTC_*|*=*) continue ;;
        esac

        # Only export if the variable is UNSET
        # Does not overwrite docker compose injections or empty strings
        if eval "[ -z \"\${${var_name}+x}\" ]"; then

          # 3. Read the file verbatim (preserving spaces and nulls)
          IFS= read -r var_value < "$file"

          # 4. CHOMP: Emulate s6-envdir trailing whitespace removal
          # Strips trailing carriage returns, tabs, and spaces
          var_value=$(printf '%s' "$var_value" | sed -e 's/[[:space:]]*$//')

          # 5. NULL-TO-NEWLINE: Emulate s6-envdir null translation
          # Converts literal null bytes (\0) into actual shell newlines
          var_value=$(printf '%s' "$var_value" | tr '\0' '\n')
          export "$var_name=$var_value"
        fi
      fi
    done
    # Clean up loop variables to keep user environment clean
    unset file var_name var_value envDir
  fi
fi