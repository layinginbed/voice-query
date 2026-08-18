#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/SayQuery.app"

cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/SayQuery" "$APP_DIR/Contents/MacOS/SayQuery"
cp "$PROJECT_DIR/AppBundle/Info.plist" "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
