#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands jq

# ─── Configuration ────────────────────────────────────────────────────────────
JSON_FILE="${1:?Provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

SCRIPT_FILE="$(dirname "$0")/sanitize_json.jq"

# ─── Invoking jq script ───────────────────────────────────────────────────────
jq -f "${SCRIPT_FILE}" "${JSON_FILE}"