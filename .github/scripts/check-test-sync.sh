#!/usr/bin/env bash

set -euo pipefail

BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-}"
PR_BODY="${PR_BODY:-}"
CHANGED_FILES="${CHANGED_FILES:-}"

if [[ -z "${CHANGED_FILES}" ]]; then
  if [[ -z "${BASE_SHA}" || -z "${HEAD_SHA}" ]]; then
    echo "BASE_SHA and HEAD_SHA are required unless CHANGED_FILES is provided."
    exit 1
  fi

  CHANGED_FILES="$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}")"
fi

if [[ -z "${CHANGED_FILES}" ]]; then
  echo "No changed files detected."
  exit 0
fi

TESTS_REGEX='(^Mercury/MercuryTests/|^Mercury/MercuryUITests/|(^|/).*(Tests|UITests)\.swift$)'
IGNORE_REGEX='(^\.github/|^docs/|\.md$|(^|/).*(Tests|UITests)\.swift$)'
IMPLEMENTATION_REGEX='(^App/|^Presentation/|^Application/|^Domain/|^Data/|^AI/|^Mercury/|^Sources/|(^|/).+\.swift$|(^|/).+\.plist$|(^|/).+\.xcodeproj/|(^|/).+\.xcworkspace/|^Package\.swift$)'

tests_changed=0
implementation_changed=0
test_files=()
implementation_files=()

while IFS= read -r file; do
  [[ -z "${file}" ]] && continue

  if [[ "${file}" =~ ${TESTS_REGEX} ]]; then
    tests_changed=1
    test_files+=("${file}")
  fi

  if [[ "${file}" =~ ${IGNORE_REGEX} ]]; then
    continue
  fi

  if [[ "${file}" =~ ${IMPLEMENTATION_REGEX} ]]; then
    implementation_changed=1
    implementation_files+=("${file}")
  fi
done <<< "${CHANGED_FILES}"

if [[ "${implementation_changed}" -eq 0 ]]; then
  echo "No implementation-sensitive changes detected."
  exit 0
fi

if [[ "${tests_changed}" -eq 1 ]]; then
  echo "Implementation-sensitive changes detected and tests were updated."
  printf 'Implementation-sensitive files:\n'
  printf ' - %s\n' "${implementation_files[@]}"
  printf 'Test files:\n'
  printf ' - %s\n' "${test_files[@]}"
  exit 0
fi

if printf '%s' "${PR_BODY}" | grep -Eiq -- '- \[[xX]\] no tests needed'; then
  echo "Implementation-sensitive changes detected, but the PR explicitly declares that no tests were needed."
  printf 'Implementation-sensitive files:\n'
  printf ' - %s\n' "${implementation_files[@]}"
  exit 0
fi

echo "Implementation-sensitive changes were detected without any test updates."
echo
echo "Add or update tests for new behavior, or check 'no tests needed' in the PR template and explain why."
echo
printf 'Implementation-sensitive files:\n'
printf ' - %s\n' "${implementation_files[@]}"
exit 1
