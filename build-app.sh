#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build
cp .build/debug/Kai Kai.app/Contents/MacOS/Kai
echo "Built Kai.app — open it or copy to /Applications"
