#!/usr/bin/env bash

set -euo pipefail

FORMAT="raw"
VALIDATE=false

while getopts "f:v" opt; do
    case $opt in
        f) FORMAT="${OPTARG}" ;;
        v) VALIDATE=true ;;
        ?) echo "Usage: $0 [-f format] [-v] json_file" >&2
           exit 1 ;;
    esac
done

shift $((OPTIND - 1))

JSON_FILE="${1:?Please provide a JSON file}"

if [[ ! -f "${JSON_FILE}" ]]; then
    echo "File not found: ${JSON_FILE}" >&2
    exit 1
fi

if [[ "${VALIDATE}" == true ]] && ! "$(dirname "$0")/validate_json.sh" "${JSON_FILE}"; then
    exit 1
fi

SCRIPT_FILE="$(dirname "$0")/extract_schema.jq"

jq -f "${SCRIPT_FILE}" --arg format "$FORMAT" "${JSON_FILE}" #--raw-output