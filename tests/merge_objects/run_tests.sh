# Overrides for tools/run_tests.sh, specific to merge_objects.sh.
# See tests/merge_objects/generate_test_results.sh for more information.

run_script() {
    "${SCRIPT}" -k id "$1"
}

normalize_output() {
    sed "s|${PROJECT_DIR}|<PROJECT_DIR>|g" | sed -E 's/^jq: error \(at [^)]*\): //'
}