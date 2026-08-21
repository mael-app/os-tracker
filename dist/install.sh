#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-mael-app/os-tracker}"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/os-tracker"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
    darwin)
        TARBALL_OS="macos"
        ;;
    linux)
        case "$ARCH" in
            x86_64) TARBALL_OS="x86_64-unknown-linux-musl" ;;
            *) echo "Unsupported Linux architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

LATEST_RELEASE=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_RELEASE" ]; then
    echo "Failed to fetch latest release version."
    exit 1
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_RELEASE}/os-tracker-${TARBALL_OS}.tar.gz"

echo "Downloading os-tracker ${LATEST_RELEASE} for ${OS}/${ARCH}..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/os-tracker.tar.gz"
tar -xzf "${TMP_DIR}/os-tracker.tar.gz" -C "$TMP_DIR"

mkdir -p "$BIN_DIR"
install -m 755 "${TMP_DIR}/os-tracker" "${BIN_DIR}/os-tracker"

mkdir -p "$CONFIG_DIR"
if [ ! -f "${CONFIG_DIR}/config.toml" ]; then
    cat << 'CONFIG_EOF' > "${CONFIG_DIR}/config.toml"
api_url = "https://os-tracker.mael-app.workers.dev"
token = "your-secret-token-here"
interval_secs = 120
CONFIG_EOF
    echo "Created default config template at ${CONFIG_DIR}/config.toml"
fi

echo "os-tracker installed successfully to ${BIN_DIR}/os-tracker"
