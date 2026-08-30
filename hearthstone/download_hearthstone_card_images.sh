#!/usr/bin/env bash

set -euo pipefail

TEMP_FILES=()

tput civis
trap 'tput cnorm; [[ ${#TEMP_FILES[@]} -gt 0 ]] && rm -f "${TEMP_FILES[@]}"' EXIT INT TERM

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands curl jq parallel

# ─── Configuration ────────────────────────────────────────────────────────────
CONFIG_FILE="${PROJECT_DIR}/common/config.json"
DATA_DIR="${PROJECT_DIR}/data/hearthstone"
DATA_FILE="hearthstone_cards.json"
IMAGES_DIR="${PROJECT_DIR}/assets/hearthstone/card_images"
PARALLEL_JOBS=150
SHOW_FAILED=false

OPTS=$(getopt -o "" --long show-failed -n "$(basename "$0")" -- "$@")

eval set -- "${OPTS}"

while true; do
    case "$1" in
        --show-failed) SHOW_FAILED=true; shift ;;
        --) shift; break ;;
         *) echo "Usage: $0 [--show-failed]" >&2;
            exit 1 ;;
    esac
done

# ─── Available locales ────────────────────────────────────────────────────────
load_locales "${CONFIG_FILE}"

# ─── Save Hearthstone cards image ─────────────────────────────────────────────
save_image() {
    local CARDS_DIR=$1
    local URL=$2
    local SAVED_FILE="${CARDS_DIR}/$(basename "${URL}")"

    local DL_CMD=(
        curl
        --silent --fail
        --retry 10 --retry-delay 6 --retry-connrefused
        --output "${SAVED_FILE}"
        "${URL}"
    )

    if ! "${DL_CMD[@]}"; then
        echo "${URL}" >> "${FAILED_URLS_FILE}"
    fi
}
export -f save_image

FAILED_URLS_FILE=$(mktemp)
TEMP_FILES+=("${FAILED_URLS_FILE}")

export FAILED_URLS_FILE

# ─── Hearthstone card images download loop ────────────────────────────────────
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

    # ─── Track progress while images download ─────────────────────────────────
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

# ─── Display errors ───────────────────────────────────────────────────────────
if [[ "${SHOW_FAILED}" == true ]] && [[ -s "${FAILED_URLS_FILE}" ]]; then
    echo "Failed images:" >&2
    cat "${FAILED_URLS_FILE}" >&2
fi