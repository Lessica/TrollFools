#!/bin/bash

set -e
cd "$(dirname "$0")"

if [ ! -z "$DEBUG" ]; then
XCCONFIG_NAME=../TrollFools/Version.Debug.xcconfig
if [ ! -f $XCCONFIG_NAME ]; then
  echo "Versioning configuration not found!"
  exit 1
fi
previous_version=$(awk -F "=" '/DEBUG_VERSION/ {print $2}' $XCCONFIG_NAME | tr -d ' ')
previous_build_number=$(awk -F "=" '/DEBUG_BUILD_NUMBER/ {print $2}' $XCCONFIG_NAME | tr -d ' ')
else
XCCONFIG_NAME=../TrollFools/Version.xcconfig
if [ ! -f $XCCONFIG_NAME ]; then
  echo "Versioning configuration not found!"
  exit 1
fi
previous_version=$(awk -F "=" '/VERSION/ {print $2}' $XCCONFIG_NAME | tr -d ' ')
previous_build_number=$(awk -F "=" '/BUILD_NUMBER/ {print $2}' $XCCONFIG_NAME | tr -d ' ')
fi

echo "$previous_version ($previous_build_number)"