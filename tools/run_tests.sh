#!/usr/bin/env bash

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT="${1:?Please provide a script to be test}"
SCRIPT_NAME=$(basename "${SCRIPT}" .sh)
TESTS_DIR="$(dirname "$0")/${SCRIPT_NAME}/tests"
PASS=0
FAIL=0
SKIP=0

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

readarray -t json_files < <(ls -v "${TESTS_DIR}"/*.json)

# --- Run tests ----------------------------------------------------------------
for json_file in "${json_files[@]}"; do
    test_name=$(basename "${json_file}" .json)
    expected_file="${TESTS_DIR}/${test_name}.txt"

    if [[ ! -f "${expected_file}" ]]; then
        echo "No expected output for ${test_name}, skipping..."
        SKIP=$((SKIP + 1))
        continue
    fi

    actual=$("${SCRIPT}" "${json_file}" 2>/dev/null)

    if diff <(echo "${actual}") "${expected_file}"; then
        echo -e "${GREEN}✓ ${test_name}${RESET}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ ${test_name}${RESET}"
        FAIL=$((FAIL + 1))
    fi
done

echo -e "\nResults: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped."