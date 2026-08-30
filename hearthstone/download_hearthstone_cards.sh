#!/usr/bin/env bash

set -euo pipefail

tput civis
trap 'tput cnorm; rm -rf "${TMP_DIR:-}"' EXIT INT TERM

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands curl jq parallel

# ─── Configuration ────────────────────────────────────────────────────────────
CONFIG_FILE="${PROJECT_DIR}/common/config.json"
MAX_PARALLEL_JOBS=30
OUTPUT_FILE="hearthstone_cards.json"
PAGE_SIZE=400
REGION="${BLIZZARD_REGION:-us}"

# ─── Available locales ────────────────────────────────────────────────────────
load_locales "${CONFIG_FILE}"

# ─── Available game modes ─────────────────────────────────────────────────────
load_gamemodes "${CONFIG_FILE}"

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
ACCESS_TOKEN=$(bash "${PROJECT_DIR}/auth/acquire_access_token.sh")

# ─── Make temp dir ────────────────────────────────────────────────────────────
TMP_DIR=$(mktemp -d)

# ─── Fetch a single Hearthstone cards page ────────────────────────────────────
get_page() {
    local LOCALE=$1
    local PAGE=$2
    local GAMEMODE=$3

    local CURL_CMD=(
        curl
        --silent --fail
        --retry 10 --retry-delay 6 --retry-connrefused
        --header "Authorization: Bearer ${ACCESS_TOKEN}"
        "${API_BASE}/hearthstone/cards?locale=${LOCALE}&page=${PAGE}&pageSize=${PAGE_SIZE}&gameMode=${GAMEMODE}&collectible=${COLLECTIBLE}"
    )

    "${CURL_CMD[@]}"
}
export -f get_page

save_page() {
    local LOCALE=$1
    local PAGE=$2
    local GAMEMODE=$3

    get_page "${LOCALE}" "${PAGE}" "${GAMEMODE}" | jq '.cards' > "${TMP_DIR}/${LOCALE}_${GAMEMODE}_page_${PAGE}.json"
}
export -f save_page

export ACCESS_TOKEN API_BASE PAGE_SIZE COLLECTIBLE TMP_DIR

# ─── Hearthstone cards download loop ──────────────────────────────────────────
for LOCALE in "${LOCALES[@]}"; do

    for GAMEMODE in "${GAMEMODES[@]}"; do

        # ─── Download first page and get total page count ─────────────────────
        echo "Downloading page 1 for gamemode ${GAMEMODE}, locale ${LOCALE}..."

        FIRST_PAGE=$(get_page "${LOCALE}" 1 "${GAMEMODE}")

        PAGE_COUNT=$(echo "${FIRST_PAGE}" | jq '.pageCount')

        if [[ -z "${PAGE_COUNT}" || "${PAGE_COUNT}" == "null" ]]; then
            echo "Failed to retrieve page count." >&2
            exit 1
        fi

        if [[ "${PAGE_COUNT}" == "0" ]]; then
            echo -e "${YELLOW}No cards found for gamemode ${GAMEMODE}, locale ${LOCALE}, skipping...${RESET}"
            continue
        else
            echo "Total pages: ${PAGE_COUNT}"
        fi

        echo "Downloading remaining pages..."

        echo "${FIRST_PAGE}" | jq '.cards' > "${TMP_DIR}/${LOCALE}_${GAMEMODE}_page_1.json"

        progress 1 $PAGE_COUNT

        JOBS=$(( PAGE_COUNT < MAX_PARALLEL_JOBS ? PAGE_COUNT : MAX_PARALLEL_JOBS ))

        # ─── Download remaining pages in parallel ─────────────────────────────
        parallel -j "${JOBS}" save_page "${LOCALE}" {} "${GAMEMODE}" ::: $(seq 2 "${PAGE_COUNT}") &

        PARALLEL_PID=$!

        # ─── Track progress while pages download ──────────────────────────────
        while kill -0 "${PARALLEL_PID}" 2>/dev/null; do
            COMPLETED=$(ls "${TMP_DIR}"/${LOCALE}_${GAMEMODE}_page_*.json 2>/dev/null | wc -l)
            progress "${COMPLETED}" "${PAGE_COUNT}"
            sleep 0.2
        done

        wait "${PARALLEL_PID}" && echo
    done

    OUTPUT_DIR="${PROJECT_DIR}/data/hearthstone/${LOCALE}" && mkdir -p "${OUTPUT_DIR}"
    SAVED_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

    # ─── Merge all pages into a single JSON array ─────────────────────────────
    jq --slurp 'add' "${TMP_DIR}"/${LOCALE}_*_page_*.json > "${SAVED_FILE}"

    CARD_COUNT=$(jq 'length' "${SAVED_FILE}")
    echo -e "${GREEN}Saved ${SAVED_FILE} (${CARD_COUNT} cards).${RESET}\n"
done