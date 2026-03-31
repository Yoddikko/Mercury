#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Mercury/Mercury.xcodeproj}"
SCHEME="${SCHEME:-Mercury}"
DESTINATION="${DESTINATION:-$(bash scripts/select-ios-simulator.sh)}"

if [[ "${DESTINATION}" == id=* ]]; then
  simulator_id="${DESTINATION#id=}"
  xcrun simctl boot "${simulator_id}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${simulator_id}" -b
fi

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -only-testing:MercuryTests \
  -skip-testing:MercuryUITests \
  test \
  CODE_SIGNING_ALLOWED=NO
