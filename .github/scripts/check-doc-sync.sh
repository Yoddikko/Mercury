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

DOCS_REGEX='^(docs/|README\.md$|CHANGELOG\.md$|CONTRIBUTING\.md$|AGENTS\.md$|CLAUDE\.md$)'
IGNORE_REGEX='(^\.github/|^docs/|\.md$|(^|/)(Tests|Test|UITests|Specs)/|(^|/).*(Tests|UITests|Specs)\.swift$)'
IMPLEMENTATION_REGEX='(^App/|^Presentation/|^Application/|^Domain/|^Data/|^AI/|^Mercury/|^Sources/|(^|/).+\.swift$|(^|/).+\.plist$|(^|/).+\.xcodeproj/|(^|/).+\.xcworkspace/|^Package\.swift$)'

docs_changed=0
implementation_changed=0
docs_files=()
implementation_files=()

while IFS= read -r file; do
  [[ -z "${file}" ]] && continue

  if [[ "${file}" =~ ${DOCS_REGEX} ]]; then
    docs_changed=1
    docs_files+=("${file}")
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

if [[ "${docs_changed}" -eq 1 ]]; then
  echo "Implementation-sensitive changes detected and documentation was updated."
  printf 'Implementation-sensitive files:\n'
  printf ' - %s\n' "${implementation_files[@]}"
  printf 'Documentation files:\n'
  printf ' - %s\n' "${docs_files[@]}"
  exit 0
fi

if printf '%s' "${PR_BODY}" | grep -Eiq -- '- \[[xX]\] no doc update needed'; then
  echo "Implementation-sensitive changes detected, but the PR explicitly declares that no docs update is needed."
  printf 'Implementation-sensitive files:\n'
  printf ' - %s\n' "${implementation_files[@]}"
  exit 0
fi

echo "Implementation-sensitive changes were detected without any docs update."
echo
echo "If behavior, models, prompts, contracts, or architecture changed, update the relevant Markdown files."
echo "If no docs update is needed, check 'no doc update needed' in the PR template and explain why."
echo
printf 'Implementation-sensitive files:\n'
printf ' - %s\n' "${implementation_files[@]}"
exit 1
