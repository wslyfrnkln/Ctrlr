#!/bin/bash

# Ctrlr Build Script for Cursor
# This script builds the iOS app from the command line

set -e  # Exit on any error

PROJECT_NAME="Ctrlr"
SCHEME_NAME="Ctrlr"
PROJECT_FILE="Ctrlr.xcodeproj"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎵 Building Ctrlr iOS App...${NC}"

# Check if Xcode is properly installed
if ! xcode-select --print-path | grep -q "Xcode.app"; then
    echo -e "${RED}❌ Error: Full Xcode installation required for iOS development${NC}"
    echo -e "${YELLOW}💡 Please install Xcode from the App Store and run:${NC}"
    echo -e "   ${BLUE}sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer${NC}"
    echo -e "   ${BLUE}xcodebuild -license accept${NC}"
    exit 1
fi

# Check if project exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo -e "${RED}❌ Error: Project file $PROJECT_FILE not found${NC}"
    exit 1
fi

# Clean previous build
echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
xcodebuild clean -project "$PROJECT_FILE" -scheme "$SCHEME_NAME" -quiet

# Build for iOS Simulator
echo -e "${YELLOW}📱 Building for iOS Simulator...${NC}"
xcodebuild build \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    -quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${BLUE}📱 App built for iOS Simulator${NC}"
    echo -e "${YELLOW}💡 Note: MIDI functionality requires a physical device${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
