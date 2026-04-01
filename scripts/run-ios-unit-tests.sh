#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Mercury/Mercury.xcodeproj}"
SCHEME="${SCHEME:-Mercury-UnitTests}"

if [[ -n "${DESTINATION:-}" ]]; then
  destination="${DESTINATION}"
elif ! destination="$(bash scripts/select-ios-simulator.sh)"; then
  echo "Failed to resolve an iOS simulator destination."
  echo "Available simulators:"
  xcrun simctl list devices available || true
  echo "Xcode destinations:"
  xcodebuild -project "${PROJECT_PATH}" -scheme "${SCHEME}" -showdestinations || true
  exit 1
fi

if [[ -z "${destination}" ]]; then
  echo "Resolved destination is empty."
  exit 1
fi

if [[ "${destination}" == id=* ]]; then
  simulator_id="${destination#id=}"
  echo "Booting simulator: ${simulator_id}"
  xcrun simctl boot "${simulator_id}" >/dev/null 2>&1 || true
  if ! xcrun simctl bootstatus "${simulator_id}" -b; then
    echo "Simulator failed to boot: ${simulator_id}"
    xcrun simctl list devices | rg "${simulator_id}" || true
    exit 1
  fi
fi

echo "Running Mercury unit tests on destination: ${destination}"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${destination}" \
  -destination-timeout 180 \
  -only-testing:MercuryTests \
  -skip-testing:MercuryUITests \
  test \
  CODE_SIGNING_ALLOWED=NO
