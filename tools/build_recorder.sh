#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/native
xcrun swiftc -O -target arm64-apple-macosx12.0 native/recorder.swift -o build/native/recorder-arm64
xcrun swiftc -O -target x86_64-apple-macosx12.0 native/recorder.swift -o build/native/recorder-x86_64
lipo -create build/native/recorder-arm64 build/native/recorder-x86_64 -output build/native/recorder
codesign --force --sign - build/native/recorder
