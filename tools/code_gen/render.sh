#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm; rm -f "${SCHEMA_FILE:-}"' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in python3; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

VENV_DIR="$(dirname "$0")/.venv"
ACTIVATE="${VENV_DIR}/bin/activate"
RENDER_SCRIPT="$(dirname "$0")/render.py"

if [[ ! -f "${ACTIVATE}" ]]; then
    echo "Virtual environment not found. Run setup.sh first." >&2
    exit 1
fi

# ─── Activate virtual environment ─────────────────────────────────────────────
source "${ACTIVATE}"

# ─── Parse options ────────────────────────────────────────────────────────────
TEMPLATE=""
CONFIG=""
CLASS_NAME=""
OUTPUT=""
DEBUG=false
HELP=false

OPTS=$(getopt -o "" --long template:,config:,class-name:,output:,debug,help -n "$(basename "$0")" -- "$@")

eval set -- "${OPTS}"

while true; do
    case "$1" in
          --template) TEMPLATE="$2"; shift 2 ;;
            --config) CONFIG="$2"; shift 2 ;;
        --class-name) CLASS_NAME="$2"; shift 2 ;;
            --output) OUTPUT="$2"; shift 2 ;;
             --debug) DEBUG=true; shift ;;
              --help) HELP=true; shift ;;
                  --) shift; break ;;
                   *) echo "Usage: $0 [--template FILE] [--config FILE] [--class-name NAME] [--output FILE] [--debug] [--help] json_file" >&2
                      exit 1 ;;
    esac
done

# ─── Display help message ─────────────────────────────────────────────────────
if [[ "${HELP}" == true ]]; then
    python3 "${RENDER_SCRIPT}" --help
    exit 0
fi

# ─── Extract JSON file schema ─────────────────────────────────────────────────
JSON_FILE="${1:?Please provide a JSON file}"

SCHEMA_FILE=$(mktemp)

"${PROJECT_DIR}"/tools/extract_schema/extract_schema.sh -f raw "${JSON_FILE}" > "${SCHEMA_FILE}"

# ─── Invoke code generator ────────────────────────────────────────────────────
PY_CMD=(
    python3 "${RENDER_SCRIPT}"
    --input "${SCHEMA_FILE}"
)
[[ -n "${TEMPLATE}" ]] && PY_CMD+=(--template "${TEMPLATE}")
[[ -n "${CONFIG}" ]] && PY_CMD+=(--config "${CONFIG}")
[[ -n "${CLASS_NAME}" ]] && PY_CMD+=(--class-name "${CLASS_NAME}")
[[ -n "${OUTPUT}" ]] && PY_CMD+=(--output "${OUTPUT}")
[[ "${DEBUG}" == true ]] && PY_CMD+=(--debug)

"${PY_CMD[@]}"