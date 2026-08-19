#!/usr/bin/env bash

set -euo pipefail

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in curl jq parallel; do
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

# ─── Configuration ────────────────────────────────────────────────────────────
DATA_DIR="$(dirname "$0")/data"
DATA_FILE="hearthstone_cards.json"
IMAGES_DIR="$(dirname "$0")/assets/card_images"
PARALLEL_JOBS=10

# ─── Available locales ────────────────────────────────────────────────────────
if [[ -z "${BLIZZARD_LOCALE:-}" ]]; then
    echo "BLIZZARD_LOCALE not set, downloading all locales..."
    LOCALES=("en_US" "es_MX" "pt_BR" "de_DE" "en_GB" "es_ES" "fr_FR" "it_IT" "pl_PL" "ru_RU" "ja_JP" "ko_KR" "th_TH" "zh_TW" "zh_CN")
else
    LOCALES=("${BLIZZARD_LOCALE}")
fi

# --- Save Hearthstone cards image ---------------------------------------------
save_image() {
    local CARDS_DIR=$1
    local URL=$2
    local SAVED_FILE="${CARDS_DIR}/$(basename "${URL}")"

    until curl --silent --fail --output "${SAVED_FILE}" "${URL}"; do sleep 5; done
}
export -f save_image

# --- Hearthstone card images download loop ------------------------------------
for LOCALE in "${LOCALES[@]}"; do

    CARDS_FILE="${DATA_DIR}/${LOCALE}/${DATA_FILE}"

    if [[ ! -f "${CARDS_FILE}" ]]; then
        echo "File not found: ${CARDS_FILE}, skipping..."
        continue
    fi

    echo "Collecting Hearthstone card image URLs for locale ${LOCALE}..."

    mapfile -t URLS < <(
        jq -r '.[] | (.image, .imageGold, .cropImage) | select(type == "string" and length > 0)' "${CARDS_FILE}" \
        | sort -u
    )

    IMAGE_COUNT="${#URLS[@]}"

    echo "Found ${IMAGE_COUNT} images."

    CARDS_DIR="${IMAGES_DIR}/${LOCALE}" && mkdir -p "${CARDS_DIR}"

    echo "Downloading..."

    URLS_FILE=$(mktemp)
    trap 'rm -f "${URLS_FILE}"' EXIT

    printf '%s\n' "${URLS[@]}" > "${URLS_FILE}"

    parallel -j ${PARALLEL_JOBS} save_image "${CARDS_DIR}" {} < "${URLS_FILE}" &

    PARALLEL_PID=$!

    # ─── Track progress while images download ──────────────────────────────---
    while kill -0 "${PARALLEL_PID}" 2>/dev/null; do
        COMPLETED=$(ls "${CARDS_DIR}" 2>/dev/null | wc -l)
        progress "${COMPLETED}" "${IMAGE_COUNT}"
        sleep 0.2
    done

    wait "${PARALLEL_PID}"

    echo -e "\nSaved ${IMAGE_COUNT} images.\n"
done