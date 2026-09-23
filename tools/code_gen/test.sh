#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands python3

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$0")"
VENV_DIR="${SCRIPT_DIR}/.venv"
ACTIVATE="${VENV_DIR}/bin/activate"

if [[ ! -f "${ACTIVATE}" ]]; then
    echo "Virtual environment not found. Run setup.sh --dev first." >&2
    exit 1
fi

# ─── Activate virtual environment ─────────────────────────────────────────────
source "${ACTIVATE}"

if ! python3 -c "import pytest" 2>/dev/null; then
    echo "pytest is not installed. Run setup.sh --dev (or upgrade.sh --dev) first." >&2
    exit 1
fi

# ─── Run tests ────────────────────────────────────────────────────────────────
cd "${SCRIPT_DIR}"

pytest -v "$@"