#!/usr/bin/env bash

# Unlike merge_objects (always invoked the same way, -k id), extract_enums
# needs a different --field value per test case, sometimes several, and
# occasionally none at all. Each test's *.json has a matching *.args file
# next to it: one --field value per line (leading slash included), used
# verbatim — an empty file means no --field flags at all, and a line that's
# missing its own leading slash or has a doubled slash is exactly how the
# "malformed path" test cases are expressed, with no special-casing needed.
#
# One sentinel: if the .args file's first line is MISSING_FILE, the JSON
# file argument itself is replaced with a path that doesn't exist, to
# exercise that specific check — the remaining lines (if any) still supply
# --field values.

run_script() {
    local json_file="$1"
    local args_file="${json_file%.json}.args"
    local -a field_args=()
    local -a lines=()
    local target_file="${json_file}"

    if [[ -f "${args_file}" ]]; then
        mapfile -t lines < "${args_file}"
    fi

    if [[ "${#lines[@]}" -gt 0 && "${lines[0]}" == "MISSING_FILE" ]]; then
        target_file="${TESTS_DIR}/does_not_exist.json"
        lines=("${lines[@]:1}")
    fi

    for line in "${lines[@]}"; do
        [[ -n "${line}" ]] && field_args+=(--field "${line}")
    done

    "${SCRIPT}" "${field_args[@]}" "${target_file}"
}

normalize_output() {
    sed "s|${PROJECT_DIR}|<PROJECT_DIR>|g" | sed -E 's/^jq: error \(at [^)]*\): //'
}