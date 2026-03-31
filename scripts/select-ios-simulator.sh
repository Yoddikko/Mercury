#!/usr/bin/env bash

set -euo pipefail

destination_id="$(
  xcrun simctl list devices available --json | python3 -c '
import json
import re
import sys

payload = json.load(sys.stdin)
candidates = []
preferred_names = [
    "iPhone 16e",
    "iPhone 16",
    "iPhone 15",
    "iPhone 15 Pro",
    "iPhone 14",
    "iPhone SE (3rd generation)",
]
name_rank = {name: index for index, name in enumerate(preferred_names)}

for runtime, devices in payload.get("devices", {}).items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue

    version = (int(match.group(1)), int(match.group(2)))

    for device in devices:
        name = device.get("name", "")
        if not name.startswith("iPhone"):
            continue

        candidates.append(
            (
                device.get("state") == "Booted",
                version,
                -name_rank.get(name, len(preferred_names)),
                name,
                device.get("udid", ""),
            )
        )

if not candidates:
    sys.exit(1)

candidates.sort(reverse=True)
print(candidates[0][4])
'
)"

if [[ -n "${destination_id}" ]]; then
  printf 'id=%s\n' "${destination_id}"
  exit 0
fi

echo "Unable to find an available iPhone simulator."
exit 1
