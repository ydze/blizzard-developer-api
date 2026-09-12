#!/usr/bin/env bash


run_script() {
    "${SCRIPT}" -k id "$1"
}


normalize_output() {
    sed "s|${PROJECT_DIR}|<PROJECT_DIR>|g" | sed -E 's/^jq: error \(at [^)]*\): //'
}