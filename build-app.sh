#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build
cp .build/debug/Kai Kai.app/Contents/MacOS/Kai
# Copy resource bundle if it exists
if [ -d ".build/debug/Kai_Kai.bundle" ]; then
    cp -r .build/debug/Kai_Kai.bundle Kai.app/Contents/Resources/Kai_Kai.bundle
fi
# Sign with stable identity so macOS permissions persist across rebuilds
codesign --force --sign "Kai Dev" Kai.app
# Install to Applications
rm -rf /Applications/Kai.app
cp -r Kai.app /Applications/Kai.app
echo "Built, signed, and installed Kai.app"
