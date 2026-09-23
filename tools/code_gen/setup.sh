#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands python3 pip3

# ─── Configuration ────────────────────────────────────────────────────────────
DEV=false

OPTS=$(getopt -o "" --long dev -n "$(basename "$0")" -- "$@")

eval set -- "${OPTS}"

while true; do
    case "$1" in
        --dev) DEV=true; shift ;;
           --) shift; break ;;
            *) echo "Usage: $0 [--dev]" >&2
               exit 1 ;;
    esac
done

SCRIPT_DIR="$(dirname "$0")"
VENV_DIR="${SCRIPT_DIR}/.venv"

if [[ "${DEV}" == true ]]; then
    REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements-dev.txt"
else
    REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
fi

# ─── Create virtual environment if it doesn't exist ───────────────────────────
if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Creating virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi

# ─── Activate virtual environment ─────────────────────────────────────────────
source "${VENV_DIR}/bin/activate"

# ─── Install dependencies ─────────────────────────────────────────────────────
echo "Installing dependencies..."

pip3 install -r "${REQUIREMENTS_FILE}"

echo "Setup complete."