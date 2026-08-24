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

# ─── Activate virtual environment ─────────────────────────────────────────----
source "${ACTIVATE}"

# --- Display help message -----------------------------------------------------
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    python3 "${RENDER_SCRIPT}" --help
    exit 0
fi

# --- Extract JSON file schema -------------------------------------------------
SCHEMA_FILE=$(mktemp)

"${PROJECT_DIR}"/tools/extract_schema/extract_schema.sh -f raw "$1" > "${SCHEMA_FILE}"

# --- Invoke code generator ----------------------------------------------------
python3 "${RENDER_SCRIPT}" --template templates/csharp.j2 --input "${SCHEMA_FILE}" --class-name BaseClass