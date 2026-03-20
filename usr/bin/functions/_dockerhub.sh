#!/bin/bash

# @description Prints the first Docker Hub username cached in the Docker Credential Cache
# @noargs
# @stdout string Docker Hub Username (or empty string)
function dockerhub::username::cached() {
  docker-credential-desktop list | jq -r 'to_entries[].value' | head -1
}

function dockerhub::username::domain() {
  hostname -f | awk -F '.' '{ printf("%s", $(NF - 1)) }'
}
