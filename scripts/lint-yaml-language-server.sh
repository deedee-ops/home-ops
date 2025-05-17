#!/usr/bin/env bash

shopt -s globstar nullglob

# Check for proper extension
check_extension() {
  local filename="$1"

  # Hardcoded list of allowed extensions (with leading dots)
  local allowed_extensions=(".yaml" ".yml" ".yaml.j2" ".yml.j2")

  for ext in "${allowed_extensions[@]}"; do
    if [[ "$filename" == *"$ext" ]]; then
      return 0
    fi
  done

  return 1
}

# Load .ylsignore patterns into an array
load_ylsignore_patterns() {
  local ignore_file="$1"
  local -n _patterns=$2

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    _patterns+=("$line")
  done < "$ignore_file"
}

# Check if a file matches any .ylsignore pattern
is_ignored() {
  local file="$1"
  local base="$2"
  shift 2
  local patterns=("$@")

  local rel_path="${file#"$base"/}"  # Make path relative to base dir

  if ! check_extension "$file"; then
    return 0
  fi

  for pat in "${patterns[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$rel_path" == $pat ]]; then
      return 0
    fi
  done
  return 1
}

# Check a YAML file's documents
check_file() {
  local file="$1"
  local doc=""
  local doc_number=0
  local has_error=0

  [[ -d "$file" ]] && return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
      if [[ -n "$doc" ]]; then
        ((doc_number++))
        if ! grep -q "^# yaml-language-server" <<< "$doc"; then
          echo "❌ Missing 'yaml-language-server' in document $doc_number of $file"
          has_error=1
        fi
      fi
      doc=""
      continue
    fi
    doc+="$line"$'\n'
  done < "$file"

  if [[ -n "$doc" ]]; then
    ((doc_number++))
    if ! grep -q "^# yaml-language-server" <<< "$doc"; then
      echo "❌ Missing 'yaml-language-server' in document $doc_number of $file"
      has_error=1
    fi
  fi

  if (( doc_number == 0 )); then
    if ! grep -q "^# yaml-language-server" "$file"; then
      echo "❌ Missing 'yaml-language-server' in document 1 of $file"
      has_error=1
    fi
  fi

  return $has_error
}

# Main file scanner
check_all_yaml_files() {
  local working_dir="."
  local root_dir="$1"
  local ignore_file="${working_dir}/.ylsignore"
  local -a ignore_patterns=()
  local any_errors=0

  if [[ -f "$ignore_file" ]]; then
    load_ylsignore_patterns "$ignore_file" ignore_patterns
  fi

  # If the root_dir is a directory, recursively find YAML files
  if [[ -d "$root_dir" ]]; then
    while IFS= read -r -d '' file; do
      if ! is_ignored "$file" "$working_dir" "${ignore_patterns[@]}"; then
        if ! check_file "$file"; then
          any_errors=1
        fi
      fi
    done < <(find "$root_dir" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.yaml.j2' -o -name '*.yml.j2' \) -print0)

  # If it's a file, process it directly
  elif [[ -f "$root_dir" ]]; then
    if ! is_ignored "$root_dir" "$working_dir" "${ignore_patterns[@]}"; then
      if ! check_file "$root_dir"; then
        any_errors=1
      fi
    fi
    return $any_errors
  fi

  # If more than one file is passed in, loop through them directly
  shift  # Shift to handle the case when there are additional files
  for file in "$@"; do
    if ! is_ignored "$file" "$working_dir" "${ignore_patterns[@]}"; then
      if ! check_file "$file"; then
        any_errors=1
      fi
    fi
  done

  return $any_errors
}

# === MAIN ===
ROOT_DIR="${1:-.}"

# If there's more than one argument, treat the first as the root dir, and the rest as file paths
if [[ "$#" -gt 1 ]]; then
  ROOT_DIR="${1}"
  shift
fi

if check_all_yaml_files "$ROOT_DIR" "$@"; then
  echo "✅ All YAML documents contain 'yaml-language-server'."
  exit 0
else
  echo "❗ Some YAML documents are missing 'yaml-language-server'."
  exit 1
fi
