#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in python3; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

VENV_DIR="$(dirname "$0")/.venv"
ACTIVATE="${VENV_DIR}/bin/activate"

if [[ ! -f "${ACTIVATE}" ]]; then
    echo "Virtual environment not found. Run setup.sh first." >&2
    exit 1
fi

# ─── Activate virtual environment ─────────────────────────────────────────----
source "${ACTIVATE}"

python3 render.py --template templates/csharp.j2 --input schema.json --class-name TestObject_1