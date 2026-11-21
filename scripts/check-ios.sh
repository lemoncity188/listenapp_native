#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
xcrun swiftc "$ROOT/ios/RedFoxListen/Session.swift" "$ROOT/ios/RedFoxListen/PlaybackRules.swift" "$ROOT/checks/main.swift" -o "$CHECK_DIR/native-check"
"$CHECK_DIR/native-check" "$ROOT/reference/aes-vectors.json"
xcodebuild -project "$ROOT/ios/RedFoxListen.xcodeproj" -target RedFoxListen -configuration Debug -sdk iphonesimulator SYMROOT="$CHECK_DIR/build" OBJROOT="$CHECK_DIR/obj" CODE_SIGNING_ALLOWED=NO build
