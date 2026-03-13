#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build
cp .build/debug/Kai Kai.app/Contents/MacOS/Kai
# Copy resource bundle if it exists
if [ -d ".build/debug/Kai_Kai.bundle" ]; then
    cp -r .build/debug/Kai_Kai.bundle Kai.app/Contents/Resources/Kai_Kai.bundle
fi
echo "Built Kai.app — open it or copy to /Applications"
