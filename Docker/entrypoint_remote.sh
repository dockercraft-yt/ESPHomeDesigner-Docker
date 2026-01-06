#!/bin/sh
set -e

TMPDIR=$(mktemp -d)
ZIP="$TMPDIR/site.zip"
REPO_ZIP_URL="https://api.github.com/repos/koosoli/ESPHomeDesigner/zipball/main"
WEBROOT="/usr/share/nginx/html"

echo "[remote_entrypoint] Temp dir: $TMPDIR"
echo "[remote_entrypoint] Downloading repo zip from: $REPO_ZIP_URL"

if ! curl -fsSL "$REPO_ZIP_URL" -o "$ZIP"; then
  echo "[remote_entrypoint] ERROR: failed to download $REPO_ZIP_URL"
  exit 1
fi

echo "[remote_entrypoint] Extracting zip"
unzip -q "$ZIP" -d "$TMPDIR"

# Find extracted repo root (there will be a single top-level folder)
EXTRACTED_DIR="$(find "$TMPDIR" -maxdepth 1 -type d -name '*ESPHomeDesigner*' | head -n 1)"
if [ -z "$EXTRACTED_DIR" ]; then
  # fallback: pick the first directory under tmp (excluding tmp itself)
  EXTRACTED_DIR="$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
fi

echo "[remote_entrypoint] Extracted dir: $EXTRACTED_DIR"

FRONTEND_DIR="$EXTRACTED_DIR/custom_components/reterminal_dashboard/frontend"
SOURCE_DIR="$FRONTEND_DIR"

# Fallback: if the frontend path above isn't present, fall back to the
# repository's `Docker/src/data` path (for backwards compatibility).
if [ ! -d "$SOURCE_DIR" ]; then
  FALLBACK_DIR="$EXTRACTED_DIR/Docker/src/data"
  if [ -d "$FALLBACK_DIR" ]; then
    SOURCE_DIR="$FALLBACK_DIR"
    echo "[remote_entrypoint] Using fallback source dir: $SOURCE_DIR"
  else
    echo "[remote_entrypoint] ERROR: expected assets not found in either $FRONTEND_DIR or $FALLBACK_DIR"
    ls -la "$EXTRACTED_DIR" || true
    rm -rf "$TMPDIR"
    exit 1
  fi
fi

echo "[remote_entrypoint] Populating webroot ($WEBROOT) from $SOURCE_DIR"
rm -rf "$WEBROOT"/* || true
cp -a "$SOURCE_DIR/." "$WEBROOT/"

# Ensure web files are readable
chmod -R a+rX "$WEBROOT" || true

echo "[remote_entrypoint] Cleaning temporary files"
rm -rf "$TMPDIR"

# Ensure TLS certs exist; generate self-signed cert if not provided
SSL_DIR="/etc/nginx/ssl"
# Configurable via environment:
# CERT_AUTOGEN: 1 (default) to auto-generate, 0 to skip generation
CERT_AUTOGEN="${CERT_AUTOGEN:-1}"

if [ ! -f "$SSL_DIR/server.crt" ] || [ ! -f "$SSL_DIR/server.key" ]; then
  if [ "$CERT_AUTOGEN" = "0" ] || [ "$CERT_AUTOGEN" = "false" ]; then
    echo "[remote_entrypoint] CERT_AUTOGEN is disabled; no certs found at $SSL_DIR; nginx may fail to start"
  else
    echo "[remote_entrypoint] No TLS cert found at $SSL_DIR — generating self-signed cert"
    mkdir -p "$SSL_DIR"
    chmod 700 "$SSL_DIR" || true
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$SSL_DIR/server.key" -out "$SSL_DIR/server.crt" \
      -subj "/CN=esphome-designer" >/dev/null 2>&1 || true
    chmod 644 "$SSL_DIR/server.crt" "$SSL_DIR/server.key" || true
  fi
fi

echo "[remote_entrypoint] Starting: $@"
exec "$@"
