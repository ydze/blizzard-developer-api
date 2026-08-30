#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands jq

# ─── Configuration ────────────────────────────────────────────────────────────
FORMAT="default"

while getopts "f:v" opt; do
    case $opt in
        f) FORMAT="${OPTARG}" ;;
        ?) echo "Usage: $0 [-f format] json_file" >&2
           exit 1 ;;
    esac
done

shift $((OPTIND - 1))

JSON_FILE="${1:?Please provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

SCRIPT_FILE="$(dirname "$0")/extract_schema.jq"

# ─── Invoking jq script ───────────────────────────────────────────────────────
jq -f "${SCRIPT_FILE}" --arg format "$FORMAT" "${JSON_FILE}" --raw-output