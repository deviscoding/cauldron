#!/bin/sh
set -e

# Disable
if [ "$CONTAINER_ENV" != "prod" ]; then
  a2enconf docker-dev
fi

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php "$@"
fi

# Execute the CMD passed in from the Dockerfile
exec "$@"

