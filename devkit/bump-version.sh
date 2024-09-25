#!/bin/bash

# This script is designed to increment the build number consistently across all
# targets.

# Usage: bump-version.sh <version>
# Example: bump-version.sh 1.0

# Usage: DEBUG=1 bump-version.sh <version>
# Example: DEBUG=1 bump-version.sh 1.0

set -e
cd "$(dirname "$0")"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION=$1

if [ ! -z "$DEBUG" ]; then

# Navigating to the 'carbonwatchuk' directory inside the source root.
XCCONFIG_NAME=../TrollFools/Version.Debug.xcconfig
if [ ! -f $XCCONFIG_NAME ]; then
  echo "Versioning configuration not found!"
  exit 1
fi

# Get the current date in the format "YYYYMMDD".
current_date=$(date "+%Y%m%d")

# Parse the 'Config.xcconfig' file to retrieve the previous build number. 
# The 'awk' command is used to find the line containing "BUILD_NUMBER"
# and the 'tr' command is used to remove any spaces.
previous_build_number=$(awk -F "=" '/DEBUG_BUILD_NUMBER/ {print $2}' $XCCONFIG_NAME | tr -d ' ')

# Extract the date part and the counter part from the previous build number.
previous_date="${previous_build_number:0:8}"
counter="${previous_build_number:8}"

# If the current date matches the date from the previous build number, 
# increment the counter. Otherwise, reset the counter to 1.
new_counter=$((current_date == previous_date ? counter + 1 : 1))

# Combine the current date and the new counter to create the new build number.
new_build_number="${current_date}${new_counter}"

# Use 'sed' command to replace the previous build number with the new build 
# number in the 'Config.xcconfig' file.
sed -i -e "/DEBUG_VERSION =/ s/= .*/= $VERSION/" $XCCONFIG_NAME
sed -i -e "/DEBUG_BUILD_NUMBER =/ s/= .*/= $new_build_number/" $XCCONFIG_NAME

# Remove the backup file created by 'sed' command.
rm -f $XCCONFIG_NAME-e

else

XCCONFIG_NAME=../TrollFools/Version.xcconfig
if [ ! -f $XCCONFIG_NAME ]; then
  echo "Versioning configuration not found!"
  exit 1
fi

previous_build_number=$(awk -F "=" '/BUILD_NUMBER/ {print $2}' $XCCONFIG_NAME | tr -d ' ')

new_build_number=$((previous_build_number + 1))

sed -i -e "/VERSION =/ s/= .*/= $VERSION/" $XCCONFIG_NAME
sed -i -e "/BUILD_NUMBER =/ s/= .*/= $new_build_number/" $XCCONFIG_NAME

rm -f $XCCONFIG_NAME-e

fi

# Create the layout directory
mkdir -p ../layout/DEBIAN

# Write the control file
cat > ../layout/DEBIAN/control << __EOF__
Package: wiki.qaq.trollfools
Name: TrollFools
Version: $VERSION-$new_build_number
Section: Applications
Depends: firmware (>= 14.0)
Architecture: iphoneos-arm
Author: Lessica <82flex@gmail.com>
Maintainer: Lessica <82flex@gmail.com>
Description: Give me 108 yuan.
__EOF__

# Set permissions
chmod 0644 ../layout/DEBIAN/control
