#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands jq

# ─── Configuration ────────────────────────────────────────────────────────────
JSON_FILE="${1:?Please provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

echo "Validating: ${JSON_FILE}..."

if jq 'empty' "${JSON_FILE}" 2>/dev/null; then
    echo -e "${GREEN}✓ JSON file is valid.${RESET}"
    exit 0
else
    echo -e "${RED}✗ JSON file is invalid.${RESET}" >&2
    exit 1
fi