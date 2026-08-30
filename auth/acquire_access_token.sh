#!/usr/bin/env bash

set -euo pipefail

source "${PROJECT_DIR}/common/common.sh"

# ─── Dependencies ─────────────────────────────────────────────────────────────
require_commands curl jq

# ─── Configuration ────────────────────────────────────────────────────────────
# CSPROJ="${CSPROJ_PATH:?Please set CSPROJ_PATH}"
# SECRETS=$(dotnet user-secrets list --project "${CSPROJ}")
# CLIENT_ID=$(echo "${SECRETS}" | grep "BlizzardDeveloperAPI:ClientId" | cut -d'=' -f2 | xargs)
# CLIENT_SECRET=$(echo "${SECRETS}" | grep "BlizzardDeveloperAPI:ClientSecret" | cut -d'=' -f2 | xargs)

CLIENT_ID="${BLIZZARD_CLIENT_ID:?Please set BLIZZARD_CLIENT_ID}"
CLIENT_SECRET="${BLIZZARD_CLIENT_SECRET:?Please set BLIZZARD_CLIENT_SECRET}"
REGION="${BLIZZARD_REGION:-us}"

# ─── Service URL ──────────────────────────────────────────────────────────────
AUTH_URL="https://${REGION}.battle.net/oauth/token"

# ─── Acquire access token ─────────────────────────────────────────────────────
AUTH_CMD=(
    curl
    --silent --fail
    --retry 10 --retry-delay 6 --retry-connrefused
    --data "grant_type=client_credentials"
    --user "${CLIENT_ID}:${CLIENT_SECRET}"
    "${AUTH_URL}"
)

echo "Acquiring access token..." >&2

AUTH_RESPONSE=$("${AUTH_CMD[@]}")

ACCESS_TOKEN=$(echo "${AUTH_RESPONSE}" | jq --raw-output '.access_token')

if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "null" ]]; then
    echo "Failed to acquire access token." >&2
    exit 1
else
    echo "Access token acquired." >&2
fi

echo "${ACCESS_TOKEN}"