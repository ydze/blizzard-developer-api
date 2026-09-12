#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT="${1:?Provide a script to generate test results for}"
SCRIPT_NAME=$(basename "${SCRIPT}" .sh)
TESTS_DIR="${PROJECT_DIR}/tests/${SCRIPT_NAME}"
TEST_COUNT=0

# ─── Default behavior ─────────────────────────────────────────────────────────
# A tool can override either function by dropping a script next to
# its own test JSONs (tests/<tool>/overloads.sh); if present, it's
# sourced here and its function definitions take over from these defaults.
run_script() {
    "${SCRIPT}" "$1"
}

normalize_output() {
    cat
}

HOOK="${TESTS_DIR}/overloads.sh"
if [[ -f "${HOOK}" ]]; then
    source "${HOOK}"
fi

readarray -t json_files < <(ls -v "${TESTS_DIR}"/*.json)

for json_file in "${json_files[@]}"; do
    test_name=$(basename "${json_file}" .json)
    output=$(run_script "${json_file}" 2>&1) || true
    echo "${output}" | normalize_output > "${TESTS_DIR}/${test_name}.txt"
    TEST_COUNT=$((TEST_COUNT + 1))
done

echo "Generated: ${TEST_COUNT} test results."