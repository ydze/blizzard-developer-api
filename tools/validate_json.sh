#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# ─── Configuration ────────────────────────────────────────────────────────────
JSON_FILE="${1:?Please provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

echo "Validating: ${JSON_FILE}..."

jq 'empty' ${JSON_FILE} && echo -e "${GREEN}✓ JSON file is valid.${RESET}" || echo -e "${RED}✗ JSON file is invalid.${RESET}"