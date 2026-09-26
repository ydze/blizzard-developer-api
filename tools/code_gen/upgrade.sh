#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands pip3

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
ACTIVATE="${VENV_DIR}/bin/activate"

if [[ "${DEV}" == true ]]; then
    REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements-dev.txt"
else
    REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
fi

if [[ ! -f "${ACTIVATE}" ]]; then
    echo "Virtual environment not found. Run setup.sh first." >&2
    exit 1
fi

# ─── Activate virtual environment ─────────────────────────────────────────────
source "${ACTIVATE}"

# ─── Upgrade dependencies ─────────────────────────────────────────────────────
echo "Upgrading dependencies..."

pip3 install --upgrade -r "${REQUIREMENTS_FILE}"

echo "Upgrade complete."