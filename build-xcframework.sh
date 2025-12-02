#!/bin/bash

# Build script for creating VendingIosSDK.xcframework
# This script builds the framework for both device and simulator architectures
# and combines them into a single XCFramework bundle.

set -e

# Configuration
SCHEME="VendingIosSDK"
FRAMEWORK_NAME="VendingIosSDK"
PROJECT_NAME="VendingIosSDK"
OUTPUT_DIR="build"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"
PROJECT_PATH="${PROJECT_NAME}.xcodeproj"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Build for iOS Device (arm64)
echo "📱 Building for iOS Device (arm64)..."
xcodebuild archive \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -destination "generic/platform=iOS" \
    -archivePath "${OUTPUT_DIR}/ios-arm64.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    | xcpretty || true

# Build for iOS Simulator (x86_64 + arm64)
echo "💻 Building for iOS Simulator (x86_64 + arm64)..."
xcodebuild archive \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "${OUTPUT_DIR}/ios-simulator.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    | xcpretty || true

# Create XCFramework
echo "📦 Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "${OUTPUT_DIR}/ios-arm64.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
    -framework "${OUTPUT_DIR}/ios-simulator.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
    -output "${XCFRAMEWORK_PATH}"

# Remove .private.swiftinterface files for security
echo "🔒 Removing private Swift interface files..."
find "${XCFRAMEWORK_PATH}" -name "*.private.swiftinterface" -delete
find "${XCFRAMEWORK_PATH}" -name "*.private.swiftinterface" -type f

echo "✅ XCFramework created at: ${XCFRAMEWORK_PATH}"
echo ""
echo "📋 Framework Info:"
xcodebuild -showBuildSettings -project "${PROJECT_PATH}" -scheme "${SCHEME}" | grep -E "(PRODUCT_NAME|MARKETING_VERSION|CURRENT_PROJECT_VERSION)" || true

echo ""
echo "🎉 Build complete! The XCFramework is ready for distribution."
echo "   Location: ${XCFRAMEWORK_PATH}"

