#!/usr/bin/env bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error=0
quiet=0
files=()
exclude_dirs=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q)
      quiet=1
      shift
      ;;
    --exclude)
      if [ -z "$2" ]; then
        echo "Error: --exclude requires a directory name." >&2
        exit 1
      fi
      exclude_dirs+=("$2")
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

# Default to current directory if no files/directories are specified
if [ ${#files[@]} -eq 0 ]; then
  files=(".")
fi

check_chart_file() {
  local chart_file="$1"

  [[ "$(basename "$chart_file")" != "Chart.yaml" ]] && return

  if [ $quiet -eq 0 ]; then
    echo "Checking $chart_file..."
  fi

  # Extract all 'repository:' lines
  repositories=$(grep -E '^\s*repository:' "$chart_file" | sed -E 's/.*repository:\s*//')

  if [[ -z "$repositories" ]]; then
    if [ $quiet -eq 0 ]; then
      echo -e "${GREEN}✔ No repository fields found in $chart_file — considered valid.${NC}"
    fi
    return
  fi

  local has_error=0
  while IFS= read -r repo; do
    repo=$(echo "$repo" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ ! "$repo" =~ ^oci:// ]]; then
      echo -e "${RED}❌ Non-OCI repository found in $chart_file:${NC} $repo"
      has_error=1
      error=1
    fi
  done <<< "$repositories"

  if [[ $has_error -eq 0 ]] && [ $quiet -eq 0 ]; then
    echo -e "${GREEN}✔ All repositories in $chart_file use oci:// protocol.${NC}"
  fi
}

is_excluded() {
  local path="$1"
  for exclude in "${exclude_dirs[@]}"; do
    if [[ "$path" == "$exclude"* ]]; then
      return 0
    fi
  done
  return 1
}

# Process files and directories
for item in "${files[@]}"; do
  if [ -d "$item" ]; then
    while IFS= read -r chart_file; do
      if ! is_excluded "$chart_file"; then
        check_chart_file "$chart_file"
      elif [ $quiet -eq 0 ]; then
        echo -e "${GREEN}✔ Skipping excluded file: $chart_file${NC}"
      fi
    done < <(find "$item" -type f -name 'Chart.yaml')
  elif [ -f "$item" ]; then
    if ! is_excluded "$item"; then
      check_chart_file "$item"
    elif [ $quiet -eq 0 ]; then
      echo -e "${GREEN}✔ Skipping excluded file: $item${NC}"
    fi
  else
    echo -e "${RED}❌ Invalid file or directory: $item${NC}"
    exit 1
  fi
done

if [ $error -eq 0 ]; then
  if [ $quiet -eq 0 ]; then
    echo -e "${GREEN}✅ All charts passed OCI repository check.${NC}"
  fi
else
  echo -e "${RED}❗ Some charts failed OCI repository check.${NC}"
  exit 1
fi
