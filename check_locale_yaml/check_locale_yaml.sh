#!/usr/bin/env bash

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
LOCALE_PATHS="${LOCALE_PATHS:-config/locales/en}"

echo "DRY_RUN: $DRY_RUN"
echo "LOCALE_PATHS:"
echo "$LOCALE_PATHS"
echo "---"

# Matches inline unquoted YAML values containing HTML with single-quoted attributes.
#
# Lokalise's YAML parser rejects these with a 400 error, even though they are
# valid Ruby YAML. Examples that fail:
#   key: Click <a href='url' target='_blank'>here</a>
#   key: Text <span class='foo'>bar</span>
#
# Safe alternatives:
#   key: "Click <a href='url' target='_blank'>here</a>"   # double-quoted
#   key: |-                                                # block scalar
#     Click <a href='url' target='_blank'>here</a>
#
# Pattern breakdown:
#   ^[[:space:]]+                          - indented line (all YAML values are indented)
#   [a-zA-Z0-9_-]+[[:space:]]*:           - YAML key followed by colon
#   [[:space:]]+                           - separator space(s)
#   [^|>"']                                - value does NOT start with |, >, ", or '
#                                            (not a block scalar or already-quoted string)
#   .*<[^>]*'                              - value contains an HTML tag with a
#                                            single-quoted attribute (e.g. href='url')
SQ="'"
PATTERN="^[[:space:]]+[a-zA-Z0-9_-]+[[:space:]]*:[[:space:]]+[^|>\"${SQ}].*<[^>]*${SQ}"

violation_count=0
violation_output=""

while IFS= read -r locale_path; do
  # Trim whitespace and skip blank lines
  locale_path="$(echo "$locale_path" | tr -d '[:space:]')"
  [[ -z "$locale_path" ]] && continue

  if [[ ! -d "$locale_path" ]]; then
    echo "WARNING: Directory '$locale_path' not found, skipping."
    continue
  fi

  echo "Scanning $locale_path..."

  while IFS= read -r -d '' file; do
    matches="$(grep -nE "$PATTERN" "$file" || true)"
    if [[ -n "$matches" ]]; then
      violation_output+="  $file:"$'\n'
      while IFS= read -r match; do
        violation_output+="    $match"$'\n'
        violation_count=$((violation_count + 1))
      done <<< "$matches"
    fi
  done < <(find "$locale_path" -name "*.yml" -print0 2>/dev/null | sort -z)

done <<< "$LOCALE_PATHS"

if [[ $violation_count -eq 0 ]]; then
  echo "All locale files are Lokalise-compatible."
  exit 0
fi

echo ""
echo "$violation_count Lokalise-incompatible value(s) found:"
echo ""
printf "%s" "$violation_output"
echo ""
echo "Inline unquoted YAML values containing HTML with single-quoted attributes"
echo "cause 400 errors when uploaded to Lokalise. Wrap them in double quotes:"
echo ""
echo "  Bad:  key: Click <a href='url' target='_blank'>here</a>"
printf "  Good: key: \"Click <a href='url' target='_blank'>here</a>\"\n"

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "(dry_run=true: not failing the workflow)"
  exit 0
fi

exit 1
