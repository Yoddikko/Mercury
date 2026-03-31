#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Mercury/Mercury.xcodeproj}"
SCHEME="${SCHEME:-Mercury}"

show_destinations="$(xcodebuild -project "${PROJECT_PATH}" -scheme "${SCHEME}" -showdestinations 2>/dev/null || true)"

destination_id="$(printf '%s\n' "${show_destinations}" | sed -n 's/.*platform:iOS Simulator[^}]*id:\([^,]*\),[^}]*name:iPhone[^}]*.*/\1/p' | head -n1)"

if [[ -n "${destination_id}" ]]; then
  printf 'id=%s\n' "${destination_id}"
  exit 0
fi

echo "Unable to find an available iOS Simulator destination for ${SCHEME}."
exit 1
