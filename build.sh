#!/bin/bash
# Build script for Lumo macOS app
# Usage: ./build.sh [--release] [--open]

set -e

PROJECT="Lumo.xcodeproj"
CONFIGURATION="Debug"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --release) CONFIGURATION="Release"; shift ;;
        --open) OPEN_AFTER=1; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

echo "Building Lumo ($CONFIGURATION)..."

# Capture xcodebuild output to a temp file so we can check its exit code
# (piping to tail would mask failures).
BUILD_LOG=$(mktemp)
xcodebuild \
    -project "$PROJECT" \
    -scheme Lumo \
    -configuration "$CONFIGURATION" \
    build \
    > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?

# Show last 5 lines of output.
tail -5 "$BUILD_LOG"
rm -f "$BUILD_LOG"

if [ "$BUILD_STATUS" -ne 0 ]; then
    echo "❌ Build failed (exit code $BUILD_STATUS)"
    exit 1
fi

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Lumo-*/Build/Products/$CONFIGURATION/Lumo.app -maxdepth 0 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Build failed - app not found"
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo "   App: $APP_PATH"
echo ""

# Copy to project dir for convenience. Remove any existing copy first —
# cp -R into an existing directory would nest the app inside it.
rm -rf ./Lumo.app
cp -R "$APP_PATH" ./Lumo.app
echo "   Also copied to: $(pwd)/Lumo.app"

if [ "$OPEN_AFTER" = "1" ]; then
    echo ""
    echo "Opening Lumo..."
    open "$APP_PATH"
fi