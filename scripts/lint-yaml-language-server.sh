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

# Load list from file to array
load_patterns() {
  local input_file="$1"
  local -n _patterns=$2

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    _patterns+=("$line")
  done < "$input_file"
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

# Validate URL
validate_url() {
  local url="$1"
  local found_urlpat=0
  for urlpat in "${url_patterns[@]}"; do
    if [[ "$url" == "$urlpat"* ]]; then
      found_urlpat=1
      break
    fi
  done
  if [ $found_urlpat -eq 0 ]; then
    echo "❌ \$schema URL is not allowed pattern, in $doc_number of $file"
    return 1
  else
    if [ -n "${YLS_RESOLVE_URLS}" ]; then
      if [[ "$(curl -o /dev/null -s -w "%{http_code}" "$url")" != "200" ]]; then
        echo "❌ \$schema URL is not working in $doc_number of $file"
        return 1
      fi
    fi
  fi

  return 0
}

# Check a YAML file's documents
check_file() {
  local file="$1"
  shift
  local url_patterns=("$@")
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
        else
          url="$(grep "^# yaml-language-server" <<< "$doc" | awk -F= '{print $NF}')"
          validate_url "$url"
          has_error=$?
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
    else
      url="$(grep "^# yaml-language-server" <<< "$doc" | awk -F= '{print $NF}')"
      validate_url "$url"
      has_error=$?
    fi
  fi

  if (( doc_number == 0 )); then
    if ! grep -q "^# yaml-language-server" "$file"; then
      echo "❌ Missing 'yaml-language-server' in document 1 of $file"
      has_error=1
    else
      url="$(grep "^# yaml-language-server" "$file" | awk -F= '{print $NF}')"
      validate_url "$url"
      has_error=$?
    fi
  fi

  return $has_error
}

# Main file scanner
check_all_yaml_files() {
  local working_dir="."
  local root_dir="$1"
  local ylsconfig="${working_dir}/.ylsconfig"
  local -a ignore_patterns=()
  local -a url_patterns=()
  local any_errors=0

  if [[ -f "$ylsconfig" ]]; then
    ignore_file="$(mktemp)"
    python -c "import json; d=json.load(open('${ylsconfig}')); [print(x) for x in d.get('ignoreFiles', [])]" > "$ignore_file"
    load_patterns "$ignore_file" ignore_patterns
    rm -f "$ignore_file"

    url_file="$(mktemp)"
    python -c "import json; d=json.load(open('${ylsconfig}')); [print(x) for x in d.get('allowOnlyURLs', [])]" > "$url_file"
    load_patterns "$url_file" url_patterns
    rm -f "$url_file"
  fi

  # If the root_dir is a directory, recursively find YAML files
  if [[ -d "$root_dir" ]]; then
    while IFS= read -r -d '' file; do
      if ! is_ignored "$file" "$working_dir" "${ignore_patterns[@]}"; then
        if ! check_file "$file" "${url_patterns[@]}"; then
          any_errors=1
        fi
      fi
    done < <(find "$root_dir" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.yaml.j2' -o -name '*.yml.j2' \) -print0)

  # If it's a file, process it directly
  elif [[ -f "$root_dir" ]]; then
    if ! is_ignored "$root_dir" "$working_dir" "${ignore_patterns[@]}"; then
      if ! check_file "$root_dir" "${url_patterns[@]}"; then
        any_errors=1
      fi
    fi
    return $any_errors
  fi

  # If more than one file is passed in, loop through them directly
  shift  # Shift to handle the case when there are additional files
  for file in "$@"; do
    if ! is_ignored "$file" "$working_dir" "${ignore_patterns[@]}"; then
      if ! check_file "$file" "${url_patterns[@]}"; then
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
  echo "✅ All YAML documents contain correct 'yaml-language-server'."
  exit 0
else
  echo "❗ Some YAML documents are missing correct 'yaml-language-server'."
  exit 1
fi
