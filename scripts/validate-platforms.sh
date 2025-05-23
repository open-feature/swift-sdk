#!/bin/bash

# Script to validate that OpenFeature builds and runs on all Apple platforms

set -e

echo "🚀 Validating OpenFeature Swift SDK on all Apple platforms..."
echo ""

# Function to run platform tests
test_platform() {
    local platform=$1
    local destination=$2
    
    echo "🧪 Testing $platform..."
    
    if [ "$platform" = "macOS" ]; then
        swift test
        echo "✅ $platform tests passed"
    else
        xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme OpenFeature -destination "$destination"
        echo "✅ $platform tests passed"
    fi
}

# Test all platforms using specific working devices
test_platform "macOS" "platform=macOS"
echo ""

test_platform "iOS" "platform=iOS Simulator,name=iPhone 16"
echo ""

test_platform "watchOS" "platform=watchOS Simulator,name=Apple Watch Series 10 (42mm)"
echo ""

test_platform "tvOS" "platform=tvOS Simulator,name=Apple TV"
echo ""

# Summary
echo "📋 Platform configuration:"
grep -A 10 "platforms:" Package.swift | head -6

echo ""
echo "🎉 OpenFeature Swift SDK platform validation completed!"
echo ""