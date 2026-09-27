#!/usr/bin/env bash

set -euo pipefail

FAILED_URLS_FILE=$(mktemp)
TEMP_FILES=("${FAILED_URLS_FILE}")

trap '[[ ${#TEMP_FILES[@]} -gt 0 ]] && rm -f "${TEMP_FILES[@]}"' EXIT INT TERM

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands curl jq parallel

# ─── Configuration ────────────────────────────────────────────────────────────
CONFIG_FILE="${PROJECT_DIR}/common/config.json"
DATA_DIR="${PROJECT_DIR}/data/hearthstone"
DATA_FILE="hearthstone_cards.json"
IMAGES_DIR="${PROJECT_DIR}/assets/hearthstone/card_images"
PARALLEL_JOBS=150
RETRY_FAILED=false

OPTS=$(getopt -o "" --long retry-failed -n "$(basename "$0")" -- "$@")

eval set -- "${OPTS}"

while true; do
    case "$1" in
        --retry-failed) RETRY_FAILED=true; shift ;;
                    --) shift; break ;;
                     *) echo "Usage: $0 [--retry-failed]" >&2;
                        exit 1 ;;
    esac
done

# ─── Available locales ────────────────────────────────────────────────────────
load_locales "${CONFIG_FILE}"

# ─── Save Hearthstone cards image ─────────────────────────────────────────────
save_image() {
    local output_dir=$1
    local url=$2
    local saved_file="${output_dir}/$(basename "${url}")"

    local dl_cmd=(
        curl
        --silent --fail
        --retry 10 --retry-delay 6 --retry-connrefused
        --output "${saved_file}"
        "${url}"
    )

    if ! "${dl_cmd[@]}"; then
        echo "${url}" >> "${FAILED_URLS_FILE}"
        return 1
    fi
}
export -f save_image

export FAILED_URLS_FILE

# ─── Hearthstone card images download loop ────────────────────────────────────
for LOCALE in "${LOCALES[@]}"; do

    OUTPUT_DIR="${IMAGES_DIR}/${LOCALE}"
    JOBLOG="${OUTPUT_DIR}/.joblog"

    if [[ "${RETRY_FAILED}" == true ]]; then
        if [[ ! -f "${JOBLOG}" ]]; then
            echo -e "${YELLOW}File not found: "${JOBLOG}" for locale ${LOCALE}, skipping...${RESET}"
            continue
        fi

        IMAGE_COUNT=$(tail -n +2 "${JOBLOG}" 2>/dev/null | wc -l)

        parallel --joblog "${JOBLOG}" -j ${PARALLEL_JOBS} --retry-failed &
    else
        CARDS_FILE="${DATA_DIR}/${LOCALE}/${DATA_FILE}"

        if [[ ! -f "${CARDS_FILE}" ]]; then
            echo -e "${YELLOW}File not found: ${CARDS_FILE}, skipping...${RESET}"
            continue
        fi

        echo "Collecting Hearthstone card image URLs for locale ${LOCALE}..."

        mapfile -t URLS < <( jq -r '.[] | .image, .imageGold, .cropImage | select(. and length > 0)' "${CARDS_FILE}" | sort -u )

        IMAGE_COUNT="${#URLS[@]}"

        echo "Found ${IMAGE_COUNT} images."

        rm -rf "${OUTPUT_DIR:?}"
        mkdir -p "${OUTPUT_DIR}"

        echo "Downloading..."

        URLS_FILE=$(mktemp)
        TEMP_FILES+=("${URLS_FILE}")

        printf '%s\n' "${URLS[@]}" > "${URLS_FILE}"
        parallel --joblog "${JOBLOG}" -j ${PARALLEL_JOBS} save_image "${OUTPUT_DIR}" {} < "${URLS_FILE}" &
    fi

    PARALLEL_PID=$!

    # ─── Track progress while images download ─────────────────────────────────
    while kill -0 "${PARALLEL_PID}" 2>/dev/null; do
        sleep 0.314
        COMPLETED=$(ls "${OUTPUT_DIR}" 2>/dev/null | wc -l)
        progress "${COMPLETED}" "${IMAGE_COUNT}"
    done

    wait "${PARALLEL_PID}" || true
    echo

    compact_joblog "${JOBLOG}"

    DOWNLOADED=$(ls "${OUTPUT_DIR}" 2>/dev/null | wc -l)
    FAILED=$(( IMAGE_COUNT - DOWNLOADED ))

    echo -e "\n${GREEN}Images: ${DOWNLOADED} downloaded, ${FAILED} failed.${RESET}"
done