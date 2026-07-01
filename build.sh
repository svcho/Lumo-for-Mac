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

xcodebuild \
    -project "$PROJECT" \
    -scheme Lumo \
    -configuration "$CONFIGURATION" \
    build \
    2>&1 | tail -5

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Lumo-*/Build/Products/$CONFIGURATION/Lumo.app -maxdepth 0 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Build failed - app not found"
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo "   App: $APP_PATH"
echo ""

# Copy to project dir for convenience
cp -R "$APP_PATH" ./Lumo.app
echo "   Also copied to: $(pwd)/Lumo.app"

if [ "$OPEN_AFTER" = "1" ]; then
    echo ""
    echo "Opening Lumo..."
    open "$APP_PATH"
fi