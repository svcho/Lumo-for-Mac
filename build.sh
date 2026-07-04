#!/bin/bash
# Build script for Lumo macOS app
# Usage: ./build.sh [--debug] [--open] [--install-dir /Applications]

set -e

PROJECT="Lumo.xcodeproj"
SCHEME="Lumo"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$(pwd)/build/DerivedData"
INSTALL_DIR="/Applications"
OPEN_AFTER=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) CONFIGURATION="Debug"; shift ;;
        --release) CONFIGURATION="Release"; shift ;;
        --open) OPEN_AFTER=1; shift ;;
        --install-dir)
            if [ -z "$2" ]; then
                echo "--install-dir requires a path"
                exit 1
            fi
            INSTALL_DIR="$2"
            shift 2
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
done

echo "Building Lumo ($CONFIGURATION)..."
echo "Using Xcode:"
xcodebuild -version

# Capture xcodebuild output to a temp file so we can check its exit code
# (piping to tail would mask failures).
BUILD_LOG=$(mktemp)
if ! xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build \
        > "$BUILD_LOG" 2>&1; then
    tail -50 "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    echo "Build failed"
    exit 1
fi

# Show last 5 lines of output.
tail -5 "$BUILD_LOG"
rm -f "$BUILD_LOG"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Lumo.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Build failed - app not found"
    exit 1
fi

INSTALL_PATH="$INSTALL_DIR/Lumo.app"

echo ""
echo "Build successful"
echo "   App: $APP_PATH"
echo ""

echo "Installing to: $INSTALL_PATH"
rm -rf "$INSTALL_PATH"
cp -R "$APP_PATH" "$INSTALL_PATH"

if [ "$OPEN_AFTER" = "1" ]; then
    echo ""
    echo "Opening Lumo..."
    open "$INSTALL_PATH"
fi
