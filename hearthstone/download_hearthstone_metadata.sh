#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands curl jq parallel

# ─── Configuration ────────────────────────────────────────────────────────────
CONFIG_FILE="${PROJECT_DIR}/common/config.json"
MAX_PARALLEL_JOBS=30
OUTPUT_FILE="metadata.json"
REGION="${BLIZZARD_REGION:-us}"

# ─── Available locales ────────────────────────────────────────────────────────
load_locales "${CONFIG_FILE}"

# ─── Service URLs ─────────────────────────────────────────────────────────────
API_BASE="https://${REGION}.api.blizzard.com"

# ─── Acquire access token ─────────────────────────────────────────────────────
ACCESS_TOKEN=$(bash "${PROJECT_DIR}/auth/acquire_access_token.sh")

# ─── Download Hearthstone Metadata ────────────────────────────────────────────
get_metadata() {
    local LOCALE=$1

    local OUTPUT_DIR="${PROJECT_DIR}/data/hearthstone/${LOCALE}"
    local SAVED_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

    mkdir -p "${OUTPUT_DIR}"

    local GET_CMD=(
        curl
        --silent --fail
        --retry 10 --retry-delay 6 --retry-connrefused
        --header "Authorization: Bearer ${ACCESS_TOKEN}"
        "${API_BASE}/hearthstone/metadata?locale=${LOCALE}"
    )

    "${GET_CMD[@]}" | jq '.' > "${SAVED_FILE}"

    echo -e "${GREEN}Saved ${SAVED_FILE}.${RESET}"
}
export -f get_metadata

export ACCESS_TOKEN API_BASE PROJECT_DIR OUTPUT_FILE GREEN RESET

LOCALE_COUNT="${#LOCALES[@]}"

JOBS=$(( LOCALE_COUNT < MAX_PARALLEL_JOBS ? LOCALE_COUNT : MAX_PARALLEL_JOBS ))

parallel -j "${JOBS}" get_metadata ::: "${LOCALES[@]}"