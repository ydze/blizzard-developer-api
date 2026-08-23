#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in pip3; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

SCRIPT_DIR="$(dirname "$0")"
VENV_DIR="${SCRIPT_DIR}/.venv"
ACTIVATE="${VENV_DIR}/bin/activate"

if [[ ! -f "${ACTIVATE}" ]]; then
    echo "Virtual environment not found. Run setup.sh first." >&2
    exit 1
fi

# ─── Activate virtual environment ─────────────────────────────────────────----
source "${ACTIVATE}"

# ─── Upgrade dependencies ─────────────────────────────────────────────────────
echo "Upgrading dependencies..."

pip3 install --upgrade -r "${SCRIPT_DIR}/requirements.txt"

echo "Upgrade complete."