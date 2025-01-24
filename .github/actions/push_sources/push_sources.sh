#!/usr/bin/env bash

ROOT_DIR=$(pwd)

# We want to transform the FILE_PATTERN string from the action input into an array,
# that way git commands parse each pattern correctly as a separate argument.
IFS=' ' read -ra FILE_PATTERNS <<< "$FILE_PATTERNS"
echo "Finding locale files - root: $ROOT_DIR"

push_to_lokalise() {
  local file=$1
  echo "Pushing file: $file"
  ./bin/lokalise2 --token "${LOKALISE_API_TOKEN}" \
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
  echo "===="
  echo "Searching files in directory: $dir"
  echo "===="

  local files
  files=$(
    if [ -z "${GITHUB_CURRENT_COMMIT}" ]
    then
      git ls-files -- "${FILE_PATTERNS[@]}"
    else
      git diff --name-only "${GITHUB_PREVIOUS_COMMIT}" "${GITHUB_CURRENT_COMMIT}" -- "${FILE_PATTERNS[@]}"
    fi | awk NF
  )

  while read -r file; do
    push_to_lokalise "$file"
  done < <(echo "${files[@]}")

  # Return to the previous directory
  popd > /dev/null || exit 1
}

# We want to make sure all directories exist before we push anything to Lokalise
for path in "${LOCALE_PATHS[@]}"; do
  if [ ! -d "$path" ]; then
    echo "Directory '$path' not found! Cannot process files."
    exit 1
  fi
done

for path in "${LOCALE_PATHS[@]}"; do
  process_files "$path"
done

# Ensure we're back at the root directory
cd "$ROOT_DIR" || exit 1
