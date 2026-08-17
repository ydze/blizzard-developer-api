#!/usr/bin/env bash

set -euo pipefail

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in curl jq; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

# ─── Progress Bar ─────────────────────────────────────────────────────────────
progress() {
    local CURRENT=$1
    local TOTAL=$2
    local WIDTH=50
    local PERCENT=$(( CURRENT * 100 / TOTAL ))
    local FILLED=$(( CURRENT * WIDTH / TOTAL ))
    local EMPTY=$(( WIDTH - FILLED ))

    printf "\r[%${FILLED}s%${EMPTY}s] %d%% (%d/%d)" \
        "$(printf '#%.0s' $(seq 1 $FILLED))" \
        "" \
        "$PERCENT" \
        "$CURRENT" \
        "$TOTAL"
}

# --- Fetch a single Hearthstone cards page ------------------------------------
get_page() {
    local ACCESS_TOKEN=$1
    local API_BASE=$2
    local LOCALE=$3
    local PAGE=$4
    local PAGE_SIZE=$5
    local GAMEMODE=$6
    local COLLECTIBLE=$7

    local CURL_CMD=(
        curl
        --silent --fail
        --header "Authorization: Bearer ${ACCESS_TOKEN}"
        "${API_BASE}/hearthstone/cards?locale=${LOCALE}&page=${PAGE}&pageSize=${PAGE_SIZE}&gameMode=${GAMEMODE}&collectible=${COLLECTIBLE}"
    )

    until "${CURL_CMD[@]}"; do
        sleep 5
    done
}

# ─── Configuration ────────────────────────────────────────────────────────────
REGION="${BLIZZARD_REGION:-us}"
PAGE_SIZE=400
OUTPUT_FILE="hearthstone_cards.json"

# ─── Available locales ────────────────────────────────────────────────────────
if [[ -z "${BLIZZARD_LOCALE:-}" ]]; then
    echo "BLIZZARD_LOCALE not set, downloading all locales..." >&2
    LOCALES=("en_US" "es_MX" "pt_BR" "de_DE" "en_GB" "es_ES" "fr_FR" "it_IT" "pl_PL" "ru_RU" "ja_JP" "ko_KR" "th_TH" "zh_TW" "zh_CN")
else
    LOCALES=("${BLIZZARD_LOCALE}")
fi

# ─── Available game modes ─────────────────────────────────────────────────────
if [[ -z "${BLIZZARD_GAMEMODE:-}" ]]; then
    echo "BLIZZARD_GAMEMODE not set, downloading all gamemodes..." >&2
    GAMEMODES=("constructed" "battlegrounds" "arena" "duels" "standard" "classic" "mercenaries")
else
    GAMEMODES=("${BLIZZARD_GAMEMODE}")
fi

# ─── Collectible filter ───────────────────────────────────────────────────────
case "${BLIZZARD_COLLECTIBLE:-all}" in
    yes) COLLECTIBLE="1" ;;
     no) COLLECTIBLE="0" ;;
    all) COLLECTIBLE="0,1" ;;
      *) echo "BLIZZARD_COLLECTIBLE: '${BLIZZARD_COLLECTIBLE}' is invalid. Use yes, no, or all." >&2
         exit 1 ;;
esac

# ─── Service URLs ─────────────────────────────────────────────────────────────
API_BASE="https://${REGION}.api.blizzard.com"

# ─── Acquire access token ─────────────────────────────────────────────────────
echo "Acquiring access token..."

ACCESS_TOKEN=$(bash "$(dirname "$0")/acquire_access_token.sh")

echo "Access token acquired."

# ─── Make temp dir ------------------------------------------------------------
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

for LOCALE in "${LOCALES[@]}"; do

    for GAMEMODE in "${GAMEMODES[@]}"; do

        # ─── Download first page and get total page count ────────────────────-
        echo "Downloading page 1 for gamemode ${GAMEMODE}, locale ${LOCALE}..."

        FIRST_PAGE=$(get_page "${ACCESS_TOKEN}" "${API_BASE}" "${LOCALE}" 1 "${PAGE_SIZE}" "${GAMEMODE}" "${COLLECTIBLE}")

        PAGE_COUNT=$(echo "${FIRST_PAGE}" | jq '.pageCount')

        if [[ -z "${PAGE_COUNT}" || "${PAGE_COUNT}" == "null" ]]; then
            echo "Failed to retrieve page count." >&2
            exit 1
        fi

        if [[ "${PAGE_COUNT}" == "0" ]]; then
            echo "No cards found for gamemode ${GAMEMODE}, locale ${LOCALE}, skipping..." >&2
            continue
        else
            echo "Total pages: ${PAGE_COUNT}"
        fi

        echo "Downloading remaining pages..."

        echo "${FIRST_PAGE}" | jq '.cards' > "${TMP_DIR}/${LOCALE}_${GAMEMODE}_page_1.json"

        progress 1 $PAGE_COUNT

        # ─── Download remaining pages and merge cards into one file ───────────
        for (( PAGE=2; PAGE<=PAGE_COUNT; PAGE++ )); do
            get_page "${ACCESS_TOKEN}" "${API_BASE}" "${LOCALE}" "${PAGE}" "${PAGE_SIZE}" "${GAMEMODE}" "${COLLECTIBLE}" \
            | jq '.cards' > "${TMP_DIR}/${LOCALE}_${GAMEMODE}_page_${PAGE}.json"
            progress $PAGE $PAGE_COUNT
        done

        echo

    done

    OUTPUT_DIR="$(dirname "$0")/data/${LOCALE}" && mkdir -p "${OUTPUT_DIR}"
    SAVED_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

    # ─── Merge all pages into a single JSON array ─────────────────────────────
    jq --slurp 'add' "${TMP_DIR}"/${LOCALE}_*_page_*.json > "${SAVED_FILE}"

    CARD_COUNT=$(jq 'length' "${SAVED_FILE}")
    echo "Saved ${SAVED_FILE} (${CARD_COUNT} cards)."
done