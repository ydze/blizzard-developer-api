#!/usr/bin/env bash


# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'


# ─── Check required dependencies ──────────────────────────────────────────────
require_commands() {
    for CMD in "$@"; do
        if ! command -v "${CMD}" &> /dev/null; then
            echo "Required command '${CMD}' is not installed." >&2
            exit 1
        fi
    done
}


# ─── Load available locales ───────────────────────────────────────────────────
load_locales() {
    local CONFIG_FILE="$1"

    if [[ -n "${BLIZZARD_LOCALE:-}" ]]; then
        LOCALES=("${BLIZZARD_LOCALE}")
        return
    fi

    echo "BLIZZARD_LOCALE not set, pulling locales from ${CONFIG_FILE}..."

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "Config file not found: ${CONFIG_FILE}" >&2
        exit 1
    fi

    mapfile -t LOCALES < <( jq -r '.locales[]' "${CONFIG_FILE}" | sort -u )
}


# ─── Load available gamemodes ─────────────────────────────────────────────────
load_gamemodes() {
    local CONFIG_FILE="$1"

    if [[ -n "${BLIZZARD_GAMEMODE:-}" ]]; then
        GAMEMODES=("${BLIZZARD_GAMEMODE}")
        return
    fi

    echo "BLIZZARD_GAMEMODE not set, pulling gamemodes from ${CONFIG_FILE}..."

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "Config file not found: ${CONFIG_FILE}" >&2
        exit 1
    fi

    mapfile -t GAMEMODES < <( jq -r '.gamemodes[]' "${CONFIG_FILE}" | sort -u )
}


# ─── Progress Bar ─────────────────────────────────────────────────────────────
progress() {
    local CURRENT=$1
    local TOTAL=$2
    local WIDTH=50
    local PERCENT=$(( CURRENT * 100 / TOTAL ))
    local FILLED=$(( CURRENT * WIDTH / TOTAL ))
    local EMPTY=$(( WIDTH - FILLED ))
    local BAR=""

    (( FILLED > 0 )) && BAR+=$(printf '#%.0s' $(seq 1 "${FILLED}"))
    (( EMPTY > 0 )) && BAR+=$(printf ' %.0s' $(seq 1 "${EMPTY}"))

    local MSG="[${BAR}] ${PERCENT}% (${CURRENT}/${TOTAL})"
    local PAD=$(( 80 - ${#MSG} ))

    printf "\r%s%${PAD}s" "${MSG}" ""
}