#!/bin/bash

# Metal Performance Tracker - Build Script
# This script builds the project and runs basic tests

set -e  # Exit on any error

echo "Building Metal Performance Tracker..."

# Build the project
echo "Building project..."
xcodebuild -project Metal-Performance-Tracker.xcodeproj \
           -scheme Metal-Performance-Tracker \
           -configuration Debug \
           build

if [ $? -eq 0 ]; then
    echo "Build successful!"
else
    echo "Build failed!"
    exit 1
fi

# Get the executable path
EXECUTABLE_PATH=$(xcodebuild -project Metal-Performance-Tracker.xcodeproj \
                            -scheme Metal-Performance-Tracker \
                            -configuration Debug \
                            -showBuildSettings | grep -E "BUILT_PRODUCTS_DIR|EXECUTABLE_NAME" | head -2 | awk '{print $3}' | tr '\n' '/' | sed 's|/$||')

echo "Executable location: $EXECUTABLE_PATH"

# Test help command
echo "Testing help command..."
"$EXECUTABLE_PATH" --help

if [ $? -eq 0 ]; then
    echo "Help command works!"
else
    echo "Help command failed!"
    exit 1
fi

echo "All tests passed! Build is ready."
