#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands jq

# ─── Configuration ────────────────────────────────────────────────────────────
FIELDS=()

OPTS=$(getopt -o "" --long field: -n "$(basename "$0")" -- "$@")

eval set -- "${OPTS}"

while true; do
    case "$1" in
        --field) FIELDS+=("$2"); shift 2 ;;
             --) shift; break ;;
              *) echo "Usage: $0 --field /path/to/field [--field /path/to/field ...] json_file" >&2
                 exit 1 ;;
    esac
done

if [[ "${#FIELDS[@]}" -eq 0 ]]; then
    echo "Provide at least one --field /path/to/field" >&2
    exit 1
fi

JSON_FILE="${1:?Provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

SCRIPT_FILE="$(dirname "$0")/extract_enums.jq"

# ─── Process each requested field ─────────────────────────────────────────────
RESULTS=()

for path in "${FIELDS[@]}"; do
    if [[ "${path}" != /* ]]; then
        echo "Invalid --field path '${path}': must start with '/'" >&2
        exit 1
    fi

    IFS='/' read -ra RAW <<< "${path}" && PARTS=("${RAW[@]:1}")

    if [[ "${#PARTS[@]}" -lt 1 ]]; then
        echo "Invalid --field path '${path}': field name is needed — e.g. /field or /section/field" >&2
        exit 1
    fi

    for part in "${PARTS[@]}"; do
        if [[ -z "${part}" ]]; then
            echo "Invalid --field path '${path}': empty segment — check for a doubled '/'" >&2
            exit 1
        fi
    done

    PATH_JSON=$(jq -n '$ARGS.positional' --args "${PARTS[@]}")
    RESULT=$(jq --argjson path "${PATH_JSON}" -f "${SCRIPT_FILE}" "${JSON_FILE}")
    IS_VALID=$(echo "${RESULT}" | jq -r '.is_valid')

    if [[ "${IS_VALID}" == false ]]; then
        KEY=$(echo "${RESULT}" | jq -r '.key')
        INVALID_VALUES=$(echo "${RESULT}" | jq -r '.invalid_values | join(",\n  ")')

        echo -e "Cannot generate enum '${KEY}' — path '${path}' contains invalid value(s):\n  ${INVALID_VALUES}" >&2
        continue
    fi

    RESULTS+=("$(echo "${RESULT}" | jq '{(.key): .values}')")
done

# ─── Combine and emit ─────────────────────────────────────────────────────────
printf '%s\n' "${RESULTS[@]}" | jq -s 'add // {}'