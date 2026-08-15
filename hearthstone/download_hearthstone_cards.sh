#!/usr/bin/env bash

set -euo pipefail

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in curl jq; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

# ─── Configuration ────────────────────────────────────────────────────────────
# CSPROJ="${CSPROJ_PATH:?Please set CSPROJ_PATH}"
# SECRETS=$(dotnet user-secrets list --project "${CSPROJ}")
# CLIENT_ID=$(echo "${SECRETS}" | grep "BlizzardDeveloperAPI:ClientId" | cut -d'=' -f2 | xargs)
# CLIENT_SECRET=$(echo "${SECRETS}" | grep "BlizzardDeveloperAPI:ClientSecret" | cut -d'=' -f2 | xargs)

CLIENT_ID="${BLIZZARD_CLIENT_ID:?Please set BLIZZARD_CLIENT_ID}"
CLIENT_SECRET="${BLIZZARD_CLIENT_SECRET:?Please set BLIZZARD_CLIENT_SECRET}"
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

# ─── Service URLs ─────────────────────────────────────────────────────────────
AUTH_URL="https://${REGION}.battle.net/oauth/token"
API_BASE="https://${REGION}.api.blizzard.com"

# ─── Acquire access token ─────────────────────────────────────────────────────
echo "Acquiring access token..."

AUTH_RESPONSE=$(curl --silent --fail --data "grant_type=client_credentials" --user "${CLIENT_ID}:${CLIENT_SECRET}" "${AUTH_URL}")

ACCESS_TOKEN=$(echo "${AUTH_RESPONSE}" | jq --raw-output '.access_token')

if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "null" ]]; then
    echo "Failed to acquire access token." >&2
    exit 1
fi

echo "Access token acquired."

# ─── Make temp dir ------------------------------------------------------------
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

for LOCALE in "${LOCALES[@]}"; do

    # ─── Download first page and get total page count ────────────────────────-
    echo "Downloading page 1 for locale ${LOCALE}..."

    until FIRST_PAGE=$(curl --silent --fail \
                            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
                            "${API_BASE}/hearthstone/cards?locale=${LOCALE}&pageSize=${PAGE_SIZE}&page=1&collectible=0,1"); do
        echo "Download failed, retrying in 5 seconds..." >&2
        sleep 5
    done

    echo "${FIRST_PAGE}" | jq '.cards' > "${TMP_DIR}/${LOCALE}_page_1.json"

    PAGE_COUNT=$(echo "${FIRST_PAGE}" | jq '.pageCount')

    if [[ -z "${PAGE_COUNT}" || "${PAGE_COUNT}" == "null" ]]; then
        echo "Failed to retrieve page count." >&2
        exit 1
    fi

    echo "Total pages: ${PAGE_COUNT}"

    # ─── Download all pages and merge cards into one file ─────────────────────
    for (( PAGE=2; PAGE<=PAGE_COUNT; PAGE++ )); do
        echo "Downloading page ${PAGE} of ${PAGE_COUNT} for locale ${LOCALE}..."

        until curl --silent --fail \
                   --header "Authorization: Bearer ${ACCESS_TOKEN}" \
                   "${API_BASE}/hearthstone/cards?locale=${LOCALE}&pageSize=${PAGE_SIZE}&page=${PAGE}&collectible=0,1" \
              | jq '.cards' > "${TMP_DIR}/${LOCALE}_page_${PAGE}.json"; do

            echo "Download failed, retrying in 5 seconds..." >&2
            sleep 5
        done
    done

    OUTPUT_DIR="data/${LOCALE}" && mkdir -p "${OUTPUT_DIR}"
    SAVED_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

    # ─── Merge all pages into a single JSON array ─────────────────────────────
    jq --slurp 'add' "${TMP_DIR}"/${LOCALE}_page_*.json > "${SAVED_FILE}"

    CARD_COUNT=$(jq 'length' "${SAVED_FILE}")
    echo "Saved ${SAVED_FILE} (${CARD_COUNT} cards)."
done