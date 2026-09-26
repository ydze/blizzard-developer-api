#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

tput civis
trap 'tput cnorm; rm -f "${SCHEMA_FILE:-}"' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands python3

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$0")"
VENV_DIR="${SCRIPT_DIR}/.venv"
ACTIVATE="${VENV_DIR}/bin/activate"
RENDER_SCRIPT="${SCRIPT_DIR}/render.py"

if [[ ! -f "${ACTIVATE}" ]]; then
    echo "Virtual environment not found. Run setup.sh first." >&2
    exit 1
fi

# ─── Activate virtual environment ─────────────────────────────────────────────
source "${ACTIVATE}"

# ─── Extract JSON file schema ─────────────────────────────────────────────────
JSON_FILE="${1:?Provide a JSON file}"

SCHEMA_FILE=$(mktemp)

"${PROJECT_DIR}"/tools/extract_schema/extract_schema.sh -f raw "${JSON_FILE}" > "${SCHEMA_FILE}"

# ─── Invoke code generator ────────────────────────────────────────────────────
cd "${SCRIPT_DIR}"

python3 "${RENDER_SCRIPT}" "$@"