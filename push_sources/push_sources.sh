#!/usr/bin/env bash

ROOT_DIR=$(pwd)
LOKALISE_CLI_PATH="${ROOT_DIR}/bin/lokalise2"
# We want to transform the FILE_PATTERN string from the action input into an array,
# that way git commands parse each pattern correctly as a separate argument.
IFS=' ' read -ra FILE_PATTERNS <<< "$FILE_PATTERNS"

echo "ROOT_DIR: $ROOT_DIR"
echo "DRY_RUN: $DRY_RUN"

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
  --poll-timeout 120s
}

process_files() {
  local dir=$1

  # Navigate to the directory passed as argument
  pushd "$dir" > /dev/null || exit 1
  echo "== Searching for files in $dir =="

  local files
  files=$(
    if [ -z "${GITHUB_CURRENT_COMMIT}" ]
    then
      git ls-files -- "${FILE_PATTERNS[@]}"
    else
      git diff --name-only "${GITHUB_PREVIOUS_COMMIT}" "${GITHUB_CURRENT_COMMIT}" -- "${FILE_PATTERNS[@]}"
    fi | awk NF
  )

  if [ -z "${files[0]}" ]
  then
    echo "No files found"
  else
    while read -r file; do
      push_to_lokalise "$file"
    done < <(echo "${files[@]}")
  fi

  # Return to the previous directory
  popd > /dev/null || exit 1
}

# ===
# Here's where the actual logic starts
# ===

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
