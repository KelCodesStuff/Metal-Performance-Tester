#!/bin/bash

# Metal Performance Regression Tracker - Test Script
# This script runs comprehensive tests of the performance tracker

set -e  # Exit on any error

echo "Running Metal Performance Tracker Tests..."

# Get the executable path
EXECUTABLE_PATH=$(xcodebuild -project Metal-Performance-Tracker.xcodeproj \
                            -scheme Metal-Performance-Tracker \
                            -configuration Debug \
                            -showBuildSettings | grep -E "BUILT_PRODUCTS_DIR|EXECUTABLE_NAME" | head -2 | awk '{print $3}' | tr '\n' '/' | sed 's|/$||')

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "Executable not found. Please run build.sh first."
    exit 1
fi

echo "Testing executable: $EXECUTABLE_PATH"

# Test 1: Help command
echo "Test 1: Help command"
"$EXECUTABLE_PATH" --help
if [ $? -eq 0 ]; then
    echo "Help command passed"
else
    echo "Help command failed"
    exit 1
fi

# Test 2: Update baseline
echo "Test 2: Update baseline"
"$EXECUTABLE_PATH" --update-baseline
if [ $? -eq 0 ]; then
    echo "Update baseline passed"
else
    echo "Update baseline failed"
    exit 1
fi

# Test 3: Run test with default threshold
echo "Test 3: Run test (default threshold)"
"$EXECUTABLE_PATH" --run-test
if [ $? -eq 0 ]; then
    echo "Run test (default) passed"
else
    echo "Run test (default) failed"
    exit 1
fi

# Test 4: Run test with custom threshold
echo "Test 4: Run test (custom threshold)"
"$EXECUTABLE_PATH" --run-test --threshold 10.0
if [ $? -eq 0 ]; then
    echo "Run test (custom) passed"
else
    echo "Run test (custom) failed"
    exit 1
fi

echo "All tests passed! Performance tracker is working correctly."
