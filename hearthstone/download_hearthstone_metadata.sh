#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in curl jq parallel; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

# ─── Configuration ────────────────────────────────────────────────────────────
REGION="${BLIZZARD_REGION:-us}"
OUTPUT_FILE="metadata.json"
MAX_PARALLEL_JOBS=30

# ─── Available locales ────────────────────────────────────────────────────────
if [[ -z "${BLIZZARD_LOCALE:-}" ]]; then
    echo "BLIZZARD_LOCALE not set, downloading all locales..."
    LOCALES=("en_US" "es_MX" "pt_BR" "de_DE" "en_GB" "es_ES" "fr_FR" "it_IT" "pl_PL" "ru_RU" "ja_JP" "ko_KR" "th_TH" "zh_TW" "zh_CN")
else
    LOCALES=("${BLIZZARD_LOCALE}")
fi

# ─── Service URLs ─────────────────────────────────────────────────────────────
API_BASE="https://${REGION}.api.blizzard.com"

# ─── Acquire access token ─────────────────────────────────────────────────────
echo "Acquiring access token..."

ACCESS_TOKEN=$(bash "$(dirname "$0")/acquire_access_token.sh")

echo "Access token acquired."

# ─── Download Hearthstone Metadata --------------------------------------------
get_metadata() {
    local LOCALE=$1

    local OUTPUT_DIR="${BASE_DIR}/data/hearthstone/${LOCALE}"
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

    echo "Saved ${SAVED_FILE}."
}
export -f get_metadata

export ACCESS_TOKEN API_BASE BASE_DIR="${PROJECT_DIR}" OUTPUT_FILE

LOCALE_COUNT="${#LOCALES[@]}"

JOBS=$(( LOCALE_COUNT < MAX_PARALLEL_JOBS ? LOCALE_COUNT : MAX_PARALLEL_JOBS ))

parallel -j "${JOBS}" get_metadata ::: "${LOCALES[@]}"