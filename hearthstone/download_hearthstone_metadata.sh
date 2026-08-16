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
API_BASE="https://${REGION}.api.blizzard.com"

# ─── Acquire access token ─────────────────────────────────────────────────────
echo "Acquiring access token..."

ACCESS_TOKEN=$(bash "$(dirname "$0")/acquire_access_token.sh")

echo "Access token acquired."

# ─── Download Hearthstone Metadata --------------------------------------------
for LOCALE in "${LOCALES[@]}"; do

    OUTPUT_DIR="$(dirname "$0")/data/${LOCALE}" && mkdir -p "${OUTPUT_DIR}"
    SAVED_FILE="${OUTPUT_DIR}/${OUTPUT_FILE}"

    until curl --silent --fail \
               --header "Authorization: Bearer ${ACCESS_TOKEN}" \
               "${API_BASE}/hearthstone/metadata?locale=${LOCALE}" \
          | jq '.' > "${SAVED_FILE}"; do

        sleep 5
    done

    echo "Saved ${SAVED_FILE}."
done