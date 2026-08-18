#!/usr/bin/env bash

set -euo pipefail

DEBUG=false

while getopts "d" opt; do
    case $opt in
        d) DEBUG=true ;;
        ?) echo "Usage: $0 [-d] json_file" >&2
           exit 1 ;;
    esac
done

shift $((OPTIND - 1))

JSON_FILE="${1:?Please provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

jq -f extract_schema.jq --argjson debug "$DEBUG" --raw-output "${JSON_FILE}"