# Overrides for tools/generate_test_results.sh, specific to merge_objects.sh.
# merge_objects.sh needs -k before its json argument, and legitimately errors
# on some inputs (conflicting values, missing keys, bad shapes) — those
# errors ARE the expected output for those test cases, so the wrapper
# strips the parts of jq's own error output that aren't portable across
# machines (the absolute path and line number it prepends).

run_script() {
    "${SCRIPT}" -k id "$1"
}

normalize_output() {
    sed "s|${PROJECT_DIR}|<PROJECT_DIR>|g" | sed -E 's/^jq: error \(at [^)]*\): //'
}