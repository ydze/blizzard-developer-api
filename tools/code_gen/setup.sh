#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

SCRIPT_DIR="$(dirname "$0")"
VENV_DIR="${SCRIPT_DIR}/.venv"

# ─── Create virtual environment if it doesn't exist ─────────────────────------
if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Creating virtual environment..."
    python -m venv "${VENV_DIR}"
fi

# ─── Activate virtual environment ─────────────────────────────────────────----
source "${VENV_DIR}/bin/activate"

# ─── Install dependencies ─────────────────────────────────────────────────────
echo "Installing dependencies..."

pip install -r "${SCRIPT_DIR}/requirements.txt"

echo "Setup complete."