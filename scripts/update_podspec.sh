#!/bin/bash

# Exit if any command fails
set -e

# Get the version from version.txt
VERSION=$(cat version.txt | tr -d '\n')

# Update the version in the podspec
sed -i '' "s/s.version.*=.*/s.version          = '$VERSION'/g" OpenFeature.podspec

echo "Updated OpenFeature.podspec to version $VERSION" 