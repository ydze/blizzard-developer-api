#!/usr/bin/env bash

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT="${1:?Please provide a script to be test}"
SCRIPT_NAME=$(basename "${SCRIPT}" .sh)
TESTS_DIR="./tests/${SCRIPT_NAME}"

for json_file in ${TESTS_DIR}/*.json; do
    test_name=$(basename "${json_file}" .json)
    ${SCRIPT} ${json_file} > "${TESTS_DIR}/${test_name}.txt"
done