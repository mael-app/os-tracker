#!/usr/bin/env bash
set -euo pipefail

WORKER_DIR="$(cd "$(dirname "$0")/../worker" && pwd)"
WRANGLER_TOML="${WORKER_DIR}/wrangler.toml"
DB_NAME="os-tracker-db"

echo "=== OS Tracker Cloudflare Setup ==="

if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Please install Node.js."
    exit 1
fi

cd "$WORKER_DIR"
npm install --silent

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo ""
    echo "🔑 Please enter your Cloudflare API Token (from dash.cloudflare.com/profile/api-tokens):"
    read -r -s INPUT_TOKEN
    echo ""
    if [ -z "$INPUT_TOKEN" ]; then
        echo "❌ Token cannot be empty."
        exit 1
    fi
    export CLOUDFLARE_API_TOKEN="$INPUT_TOKEN"
fi

echo "📡 Checking accounts associated with your token..."
WHOAMI_OUTPUT=$(npx wrangler whoami 2>&1 || true)
echo "$WHOAMI_OUTPUT"

# Auto-detect or prompt for Account ID
if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    DETECTED_ID=$(echo "$WHOAMI_OUTPUT" | grep -A 2 "Maël" | grep -oE '[a-f0-9]{32}' | head -1 || true)
    if [ -z "$DETECTED_ID" ]; then
        DETECTED_ID=$(echo "$WHOAMI_OUTPUT" | grep -oE '[a-f0-9]{32}' | head -1 || true)
    fi

    if [ -n "$DETECTED_ID" ]; then
        echo "👉 Using Account ID: ${DETECTED_ID}"
        export CLOUDFLARE_ACCOUNT_ID="$DETECTED_ID"
    else
        echo "Please enter your Cloudflare Account ID:"
        read -r INPUT_ACCOUNT_ID
        export CLOUDFLARE_ACCOUNT_ID="$INPUT_ACCOUNT_ID"
    fi
fi

# Check if database_id is already in wrangler.toml
CURRENT_DB_ID=$(grep -oE 'database_id = "[^"]+"' "${WRANGLER_TOML}" | cut -d'"' -f2 || true)

if [ -z "$CURRENT_DB_ID" ]; then
    echo ""
    echo "🗃️ Provisioning D1 Database: ${DB_NAME}..."
    D1_CREATE_OUTPUT=$(npx wrangler d1 create "${DB_NAME}" 2>&1 || true)
    DB_ID=$(echo "$D1_CREATE_OUTPUT" | grep -oE 'database_id = "[^"]+"' | cut -d'"' -f2 || true)

    if [ -z "$DB_ID" ]; then
        DB_ID=$(npx wrangler d1 list 2>&1 | grep -B 2 "${DB_NAME}" | grep -oE '[a-f0-9-]{36}' | head -1 || true)
    fi

    if [ -n "$DB_ID" ]; then
        echo "✅ D1 database ID: ${DB_ID}"
        sed -i "s|database_id = \".*\"|database_id = \"${DB_ID}\"|" "${WRANGLER_TOML}"
    fi
else
    echo "✅ Using existing D1 database ID from wrangler.toml: ${CURRENT_DB_ID}"
fi

echo ""
echo "📋 Applying D1 migrations..."
echo "y" | npx wrangler d1 migrations apply "${DB_NAME}" --remote

echo ""
echo "🔐 Configuring AUTH_TOKEN secret (the password your daemon will use to send heartbeats)..."
echo "Enter a secret token for your daemon (e.g. random string or password):"
read -r -s AUTH_TOKEN_INPUT
echo ""
if [ -n "$AUTH_TOKEN_INPUT" ]; then
    echo "$AUTH_TOKEN_INPUT" | npx wrangler secret put AUTH_TOKEN
fi

echo ""
echo "🚀 Deploying Worker..."
npx wrangler deploy

echo ""
echo "=== Setup Complete! ==="
