#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands du jq

# ─── Configuration ────────────────────────────────────────────────────────────
UNIQUE_FIELD=""

OPTS=$(getopt -o "" --long unique: -n "$(basename "$0")" -- "$@")

eval set -- "${OPTS}"

while true; do
    case "$1" in
        --unique) UNIQUE_FIELD="$2"; shift 2 ;;
              --) shift; break ;;
               *) echo "Usage: $0 [--unique field] json_file" >&2
                  exit 1 ;;
    esac
done

JSON_FILE="${1:?Provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

echo "Validating: ${JSON_FILE}..."

if ! jq 'empty' "${JSON_FILE}" 2>/dev/null; then
    echo -e "${RED}✗ JSON file is invalid.${RESET}" >&2
    exit 1
fi

echo -e "${GREEN}✓ JSON file is valid.${RESET}\n"

# ─── Gather stats ─────────────────────────────────────────────────────────────
FILE_SIZE=$(du -h "${JSON_FILE}" | cut -f1)
ROOT_TYPE=$(jq -r 'type' "${JSON_FILE}")

print_title_border "JSON Object Statistics"

print_top_border

print_row "File" "$(basename "${JSON_FILE}")"
print_row "Size" "${FILE_SIZE}"
print_row "Root Type" "${ROOT_TYPE}"

if [[ "${ROOT_TYPE}" == "array" ]]; then
    ARRAY_LENGTH=$(jq 'length' "${JSON_FILE}")
    print_row "Array Length" "${ARRAY_LENGTH}"

    if [[ "${ARRAY_LENGTH}" -gt 0 ]]; then
        ELEMENT_TYPES=$(jq -r 'map(type) | group_by(.) | map("\(.[0]) (\(length))") | join(", ")' "${JSON_FILE}")
        print_row "Element Types" "${ELEMENT_TYPES}"

        if [[ -n "${UNIQUE_FIELD}" ]]; then
            if ! jq -e 'all(.[]; type == "object")' "${JSON_FILE}" > /dev/null; then
                print_bottom_border
                echo "Cannot compute --unique '${UNIQUE_FIELD}': not every array element is an object." >&2
                exit 1
            fi

            UNIQUE_COUNT=$(jq --arg key "${UNIQUE_FIELD}" 'map(.[$key]) | unique | length' "${JSON_FILE}")
            DUPLICATE_COUNT=$((ARRAY_LENGTH - UNIQUE_COUNT))

            print_row "Unique Field" "${UNIQUE_FIELD}"
            print_row "Unique Count" "${UNIQUE_COUNT}"
            print_row "Duplicate Count" "${DUPLICATE_COUNT}"
        fi
    fi
fi

print_bottom_border