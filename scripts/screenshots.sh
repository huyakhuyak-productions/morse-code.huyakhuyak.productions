#!/usr/bin/env bash
# Regenerates docs/store/screenshots/ end to end: runs ScreenshotUITests on the 6.9" iPhone
# simulator in dark appearance, then composes the raw captures with their captions.
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${SCREENSHOT_SIMULATOR:-9854302D-7DDE-4429-B4AF-C276ABEF8497}"   # iPhone 17 Pro Max
WORK="${TMPDIR:-/tmp}/MorseLamp-screenshots"
RAW="$WORK/raw"
OUT=docs/store/screenshots

mkdir -p "$RAW"
xcrun simctl bootstatus "$SIM" -b >/dev/null   # -b: boot if needed; simctl has no long form
xcrun simctl ui "$SIM" appearance dark
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3

# xcodebuild strips the TEST_RUNNER_ prefix and hands SCREENSHOT_DIR to the test runner.
TEST_RUNNER_SCREENSHOT_DIR="$RAW" xcodebuild test \
  -project MorseLamp.xcodeproj -scheme MorseLamp \
  -destination "platform=iOS Simulator,id=$SIM" \
  -parallel-testing-enabled NO \
  -only-testing:MorseLampUITests/ScreenshotUITests \
  -derivedDataPath "$WORK/DerivedData" \
  -quiet

swift scripts/compose-screenshots.swift "$RAW" "$OUT"
