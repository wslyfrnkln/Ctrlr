#!/bin/bash
set -e

if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
fi

cd "$(dirname "$0")"
xcodegen generate --spec project.yml
echo "✓ CtrlrHelper.xcodeproj generated — open and build with Xcode"
