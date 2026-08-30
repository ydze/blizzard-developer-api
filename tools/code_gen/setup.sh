#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands python3 pip3

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$0")"
VENV_DIR="${SCRIPT_DIR}/.venv"

# ─── Create virtual environment if it doesn't exist ─────────────────────------
if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Creating virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi

# ─── Activate virtual environment ─────────────────────────────────────────----
source "${VENV_DIR}/bin/activate"

# ─── Install dependencies ─────────────────────────────────────────────────────
echo "Installing dependencies..."

pip3 install -r "${SCRIPT_DIR}/requirements.txt"

echo "Setup complete."