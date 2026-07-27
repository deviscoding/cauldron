#!/bin/bash
set -e

# @file fix-debian-sources
# @brief Performs adjustments to /etc/apt/sources for archived Debian versions.
# @author AMJones <am@jonesiscoding.com>

# @brief Adapts /etc/apt/sources.list for Debian Jessie, which has been archived.
# @noargs
function for-jessie() {
  rm /etc/apt/sources.list
  {
    echo "deb http://archive.debian.org/debian/ jessie main non-free contrib"
    echo "deb http://archive.debian.org/debian-security jessie/updates main contrib non-free"
  } > /etc/apt/sources.list
  apt-get update -o Acquire::AllowInsecureRepositories=true && apt-get install -y --allow-unauthenticated -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true debian-archive-keyring
}

# @brief Adapts /etc/apt/sources.list for Debian Stretch, which has been archived.
# @noargs
function for-stretch() {
  rm /etc/apt/sources.list
  {
    echo "deb http://archive.debian.org/debian/ stretch main non-free contrib"
    echo "deb http://archive.debian.org/debian-security stretch/updates main contrib non-free"
  } > /etc/apt/sources.list
  apt-get update -o Acquire::AllowInsecureRepositories=true && apt-get install -y --allow-unauthenticated -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true debian-archive-keyring
  echo "deb http://archive.debian.org/debian stretch-backports main contrib non-free" >> /etc/apt/sources.list
}

#
# Main Code
#

osName="$1"
if [ "$osName" = "jessie" ] || [ "$osName" = "stretch" ]; then
  echo "### Start: Fixing sources.list for $osName ###"
  case "$osName" in
  jessie)  for-jessie ;;
  stretch) for-stretch ;;
  *) ;;
  esac
  echo  "### End: Fixing sources.list for $osName ###"
fi