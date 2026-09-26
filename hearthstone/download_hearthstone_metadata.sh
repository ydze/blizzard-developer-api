#!/usr/bin/env bash

set -euo pipefail

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
    set -euo pipefail

    local locale=$1

    local output_dir="${PROJECT_DIR}/data/hearthstone/${locale}"
    local saved_file="${output_dir}/${OUTPUT_FILE}"

    mkdir -p "${output_dir}"

    local get_cmd=(
        curl
        --silent --fail
        --retry 10 --retry-delay 6 --retry-connrefused
        "${API_BASE}/hearthstone/metadata?locale=${locale}"
    )

    "${get_cmd[@]}" --header @<(printf 'Authorization: Bearer %s' "${ACCESS_TOKEN}") | jq '.' > "${saved_file}.part"
    mv "${saved_file}.part" "${saved_file}"

    echo -e "${GREEN}Saved ${saved_file}.${RESET}"
}
export -f get_metadata

export ACCESS_TOKEN API_BASE PROJECT_DIR OUTPUT_FILE GREEN RESET

LOCALE_COUNT="${#LOCALES[@]}"

JOBS=$(( LOCALE_COUNT < MAX_PARALLEL_JOBS ? LOCALE_COUNT : MAX_PARALLEL_JOBS ))

parallel -j "${JOBS}" get_metadata ::: "${LOCALES[@]}"