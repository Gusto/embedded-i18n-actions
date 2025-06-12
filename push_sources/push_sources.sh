#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

ROOT_DIR=$(pwd)
LOKALISE_CLI_PATH="${ROOT_DIR}/bin/lokalise2"
# We want to transform the FILE_PATTERN string from the action input into an array,
# that way git commands parse each pattern correctly as a separate argument.
IFS=' ' read -ra FILE_PATTERNS <<< "$FILE_PATTERNS"

# Set default value for DRY_RUN if not provided
DRY_RUN="${DRY_RUN:-false}"

echo "ROOT_DIR: $ROOT_DIR"
echo "DRY_RUN: $DRY_RUN"
echo "GITHUB_PREVIOUS_COMMIT: ${GITHUB_PREVIOUS_COMMIT:-'not set'}"
echo "GITHUB_CURRENT_COMMIT: ${GITHUB_CURRENT_COMMIT:-'not set'}"

validate_lokalise_bin() {
  if [ ! -f "$LOKALISE_CLI_PATH" ]
  then
    echo "ERROR: Lokalise binary couldn't be found: $LOKALISE_CLI_PATH"
    exit 1
  fi
}

push_to_lokalise() {
  local file=$1
  echo "Pushing file: $file"
  if [ "$DRY_RUN" == "true" ]
  then
    return
  fi

  "${LOKALISE_CLI_PATH}" --token "${LOKALISE_API_TOKEN}" \
  --project-id "${LOKALISE_PROJECT_ID}" \
  file upload --file="${file}" \
  --lang-iso en \
  --replace-modified \
  --include-path \
  --apply-tm \
  --cleanup-mode \
  --convert-placeholders=false \
  --distinguish-by-file=true \
  --poll-timeout 120s
}

verify_commit_exists() {
  local commit=$1
  if ! git cat-file -e "$commit" 2>/dev/null; then
    return 1
  fi
  return 0
}

get_files_list() {
  local files=""

  # If we have both commit references, try to use them
  if [ -n "${GITHUB_CURRENT_COMMIT:-}" ] && [ -n "${GITHUB_PREVIOUS_COMMIT:-}" ]; then
    echo "Attempting to get changed files between commits..."

    # Verify both commits exist
    if verify_commit_exists "$GITHUB_PREVIOUS_COMMIT" && verify_commit_exists "$GITHUB_CURRENT_COMMIT"; then
      echo "Both commits found, getting diff between $GITHUB_PREVIOUS_COMMIT and $GITHUB_CURRENT_COMMIT"
      files=$(git diff --name-only "$GITHUB_PREVIOUS_COMMIT" "$GITHUB_CURRENT_COMMIT" -- "${FILE_PATTERNS[@]}" 2>/dev/null | awk NF || true)

      if [ -n "$files" ]; then
        echo "Found changed files via git diff"
        echo "$files"
        return 0
      else
        echo "No changed files found via git diff"
      fi
    else
      echo "WARNING: One or both commits not found in repository:"
      if ! verify_commit_exists "$GITHUB_PREVIOUS_COMMIT"; then
        echo "  - Previous commit $GITHUB_PREVIOUS_COMMIT not found"
      fi
      if ! verify_commit_exists "$GITHUB_CURRENT_COMMIT"; then
        echo "  - Current commit $GITHUB_CURRENT_COMMIT not found"
      fi
      echo "Falling back to listing all matching files..."
    fi
  else
    echo "Commit references not available, listing all matching files..."
  fi

  # Fallback: get all files matching the patterns
  echo "Getting all files matching patterns: ${FILE_PATTERNS[*]}"
  files=$(git ls-files -- "${FILE_PATTERNS[@]}" 2>/dev/null | awk NF || true)

  if [ -n "$files" ]; then
    echo "Found files via git ls-files"
  else
    echo "No files found via git ls-files"
  fi

  echo "$files"
}

process_files() {
  local dir=$1
  echo "== Searching for files in $dir =="

  local files
  files=$(get_files_list)

  if [ -z "${files[0]}" ]
  then
    echo "No files found"
    return 0
  fi

  while read -r file; do
    if [[ "$file" == "$dir"* ]]
    then
      push_to_lokalise "$file"
    fi
  done < <(echo "${files[@]}")
}

# ===
# Here's where the actual logic starts
# ===

echo "Starting file processing..."

# We want to make sure all directories exist before we push anything to Lokalise
while read -r path; do
  if [ ! -d "$path" ]; then
    echo "ERROR: Directory '$path' not found! Cannot process files."
    exit 1
  fi
done < <(echo "${LOCALE_PATHS[@]}" | awk NF)

validate_lokalise_bin

while read -r path; do
  process_files "$path"
done < <(echo "${LOCALE_PATHS[@]}" | awk NF)

# Ensure we're back at the root directory
cd "$ROOT_DIR" || exit 1

echo "Script completed successfully"
