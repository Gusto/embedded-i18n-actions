#!/usr/bin/env bash
set -euo pipefail

output=$(ruby check_locale_yaml/check_locale_yaml.rb)
echo "$output"

expected=2
actual=$(echo "$output" | grep -E "^[0-9]+ Lokalise-incompatible" | grep -oE "^[0-9]+" || echo "0")
if [ "$actual" != "$expected" ]; then
  echo "Expected $expected violations, got $actual"
  exit 1
fi
echo "Detected $expected violations as expected"
