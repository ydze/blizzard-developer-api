#!/usr/bin/env bash


# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'
CLEAR_LINE='\033[K'


# ─── Check required dependencies ──────────────────────────────────────────────
require_commands() {
    for cmd in "$@"; do
        if ! command -v "${cmd}" &> /dev/null; then
            echo "Required command '${cmd}' is not installed." >&2
            exit 1
        fi
    done
}


# ─── Load available locales ───────────────────────────────────────────────────
load_locales() {
    local config_file="$1"

    if [[ -n "${BLIZZARD_LOCALE:-}" ]]; then
        LOCALES=("${BLIZZARD_LOCALE}")
        return
    fi

    echo "BLIZZARD_LOCALE not set, pulling locales from ${config_file}..."

    if [[ ! -f "${config_file}" ]]; then
        echo "Config file not found: ${config_file}" >&2
        exit 1
    fi

    mapfile -t LOCALES < <( jq -r '.locales[]' "${config_file}" | sort -u )
}


# ─── Load available gamemodes ─────────────────────────────────────────────────
load_gamemodes() {
    local config_file="$1"

    if [[ -n "${BLIZZARD_GAMEMODE:-}" ]]; then
        GAMEMODES=("${BLIZZARD_GAMEMODE}")
        return
    fi

    echo "BLIZZARD_GAMEMODE not set, pulling gamemodes from ${config_file}..."

    if [[ ! -f "${config_file}" ]]; then
        echo "Config file not found: ${config_file}" >&2
        exit 1
    fi

    mapfile -t GAMEMODES < <( jq -r '.gamemodes[]' "${config_file}" | sort -u )
}


# ─── Progress Bar ─────────────────────────────────────────────────────────────
progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar=""

    (( filled > 0 )) && bar+=$(printf '#%.0s' $(seq 1 "${filled}"))
    (( empty > 0 )) && bar+=$(printf ' %.0s' $(seq 1 "${empty}"))

    local msg="[${bar}] ${percent}% (${current}/${total})"

    printf "\r${CLEAR_LINE}%s" "${msg}"
}


# ─── Table ────────────────────────────────────────────────────────────────────
TABLE_WIDTH=80
LABEL_WIDTH="${LABEL_WIDTH:-18}"
VALUE_WIDTH=$((TABLE_WIDTH - LABEL_WIDTH - 7))
PADDING=2

repeat() {
    local char="$1"
    local length="$2"

    (( length > 0 )) && printf "${char}%.0s" $(seq 1 "${length}")

    return 0
}

print_row() {
    local label="$1"
    shift
    local -a items=("$@")

    local draw_label=true

    for item in "${items[@]}"; do
        if [[ "${draw_label}" == true ]]; then
            printf "│ %-${LABEL_WIDTH}s │ %-${VALUE_WIDTH}s │\n" "${label}" "${item}"
            draw_label=false
        else
            printf "│ %-${LABEL_WIDTH}s │ %-${VALUE_WIDTH}s │\n" "" "${item}"
        fi
    done
}

print_title_border() {
    local title=" $1 "
    local lspan=$(((TABLE_WIDTH - 2 - ${#title}) / 2))
    local rspan=$(((TABLE_WIDTH - 2 - ${#title}) - lspan))
    printf "╭%s%s%s╮\n" "$(repeat ─ "${lspan}")" "${title}" "$(repeat ─ "${rspan}")"
}

print_top_border() {
    printf "├%s┬%s┤\n" "$(repeat ─ $((LABEL_WIDTH + PADDING)))" "$(repeat ─ $((VALUE_WIDTH + PADDING)))"
}

print_bottom_border() {
    printf "╰%s┴%s╯\n" "$(repeat ─ $((LABEL_WIDTH + PADDING)))" "$(repeat ─ $((VALUE_WIDTH + PADDING)))"
}