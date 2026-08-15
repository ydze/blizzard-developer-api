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
OUTPUT_FILE="metadata.json"

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

# ─── Download Hearthstone Metadata --------------------------------------------
for LOCALE in "${LOCALES[@]}"; do

    OUTPUT_DIR="data/${LOCALE}" && mkdir -p "${OUTPUT_DIR}"
    SAVED_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

    until curl --silent --fail \
               --header "Authorization: Bearer ${ACCESS_TOKEN}" \
               "${API_BASE}/hearthstone/metadata?locale=${LOCALE}" \
          | jq '.' > "${SAVED_FILE}"; do

        echo "Download failed, retrying in 5 seconds..." >&2
        sleep 5
    done

    echo "Saved ${SAVED_FILE}."
done