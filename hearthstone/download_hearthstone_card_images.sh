#!/usr/bin/env bash

set -euo pipefail

TEMP_FILES=()

tput civis
trap 'tput cnorm; [[ ${#TEMP_FILES[@]} -gt 0 ]] && rm -f "${TEMP_FILES[@]}"' EXIT INT TERM

# ─── Dependencies ─────────────────────────────────────────────────────────────
for CMD in curl jq parallel; do
    if ! command -v "${CMD}" &> /dev/null; then
        echo "Required command '${CMD}' is not installed." >&2
        exit 1
    fi
done

SHOW_FAILED=false

OPTS=$(getopt -o "" --long show-failed -- "$@")
eval set -- "${OPTS}"

while true; do
    case "$1" in
        --show-failed) SHOW_FAILED=true; shift ;;
        --) shift; break ;;
         *) echo "Usage: $0 [--show-failed]" >&2; exit 1 ;;
    esac
done

# ─── Progress Bar ─────────────────────────────────────────────────────────────
progress() {
    local CURRENT=$1
    local TOTAL=$2
    local WIDTH=50
    local PERCENT=$(( CURRENT * 100 / TOTAL ))
    local FILLED=$(( CURRENT * WIDTH / TOTAL ))
    local EMPTY=$(( WIDTH - FILLED ))
    local MSG="[$(printf '#%.0s' $(seq 1 $FILLED))$(printf ' %.0s' $(seq 1 $EMPTY))] ${PERCENT}% (${CURRENT}/${TOTAL})"
    local PAD=$(( 80 - ${#MSG} ))

    printf "\r%s%${PAD}s" "${MSG}" ""
}

# ─── Configuration ────────────────────────────────────────────────────────────
DATA_DIR="${PROJECT_DIR}/data/hearthstone"
DATA_FILE="hearthstone_cards.json"
IMAGES_DIR="${PROJECT_DIR}/assets/hearthstone/card_images"
PARALLEL_JOBS=100

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
    local ATTEMPTS=0
    local MAX_ATTEMPTS=5

    until curl --silent --fail --output "${SAVED_FILE}" "${URL}"; do
        ATTEMPTS=$(( ATTEMPTS + 1 ))
        if [[ "${ATTEMPTS}" -ge "${MAX_ATTEMPTS}" ]]; then
            echo "${URL}" >> "${FAILED_URLS_FILE}"
            return 0
        fi
        sleep 5
    done
}
export -f save_image

FAILED_URLS_FILE=$(mktemp)
TEMP_FILES+=("${FAILED_URLS_FILE}")

export FAILED_URLS_FILE

# --- Hearthstone card images download loop ------------------------------------
for LOCALE in "${LOCALES[@]}"; do

    CARDS_FILE="${DATA_DIR}/${LOCALE}/${DATA_FILE}"

    if [[ ! -f "${CARDS_FILE}" ]]; then
        echo "File not found: ${CARDS_FILE}, skipping..."
        continue
    fi

    echo "Collecting Hearthstone card image URLs for locale ${LOCALE}..."

    mapfile -t URLS < <( jq -r '.[] | .image, .imageGold, .cropImage | select(. and length > 0)' "${CARDS_FILE}" | sort -u )

    IMAGE_COUNT="${#URLS[@]}"

    echo "Found ${IMAGE_COUNT} images."

    CARDS_DIR="${IMAGES_DIR}/${LOCALE}" && mkdir -p "${CARDS_DIR}"

    echo "Downloading..."

    URLS_FILE=$(mktemp)
    TEMP_FILES+=("${URLS_FILE}")

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

    DOWNLOADED=$(ls "${CARDS_DIR}" 2>/dev/null | wc -l)
    SKIPPED=$(( IMAGE_COUNT - DOWNLOADED ))

    echo -e "\nImages: ${DOWNLOADED} downloaded, ${SKIPPED} failed.\n"
done

# --- Display errors -----------------------------------------------------------
if [[ "${SHOW_FAILED}" == "true" ]] && [[ -s "${FAILED_URLS_FILE}" ]]; then
    echo "Failed images:" >&2
    cat "${FAILED_URLS_FILE}" >&2
fi