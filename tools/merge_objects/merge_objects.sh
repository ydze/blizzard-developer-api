#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands jq

# ─── Configuration ────────────────────────────────────────────────────────────
KEY=""

while getopts "k:" opt; do
    case $opt in
        k) KEY="${OPTARG}" ;;
        ?) echo "Usage: $0 [-k key] json_file" >&2
           exit 1 ;;
    esac
done

shift $((OPTIND - 1))

if [[ "${KEY}" =~ ^[[:space:]]*$ ]]; then
    echo "Provide a key to group objects by" >&2
    exit 1
fi

JSON_FILE="${1:?Please provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

SCRIPT_FILE="$(dirname "$0")/merge_objects.jq"

# ─── Invoking jq script ───────────────────────────────────────────────────────
jq -f "${SCRIPT_FILE}" --arg key "$KEY" "${JSON_FILE}" --raw-output