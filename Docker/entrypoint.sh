#!/bin/sh
set -e

echo "[entrypoint] Preparing nginx webroot..."

# If a host bind mount is provided at /usr/share/nginx/html, prefer it and
# avoid overwriting. If the directory is empty or only contains the default
# nginx index, populate it from the image's `/opt/site_src`.

WEBROOT=/usr/share/nginx/html
SRC_DIR=/opt/site_src


# Determine whether the current webroot looks like the default nginx content
# or is empty. If so, populate it from our site source. If the webroot
# already contains user-provided files (e.g. from a bind mount), do not
# overwrite them.
looks_like_default() {
	# Empty directory
	if [ -z "$(ls -A "$WEBROOT" 2>/dev/null)" ]; then
		return 0
	fi

	# Default nginx welcome pages are commonly present (index.html, 50x.html)
	if [ -f "$WEBROOT/50x.html" ]; then
		return 0
	fi

	# If index.html exists and contains the "Welcome to nginx" banner,
	# treat as default content.
	if [ -f "$WEBROOT/index.html" ]; then
		if grep -q "Welcome to nginx" "$WEBROOT/index.html" 2>/dev/null; then
			return 0
		fi
	fi

	return 1
}

if [ -d "$SRC_DIR" ]; then
	if looks_like_default; then
		echo "[entrypoint] Populating $WEBROOT from $SRC_DIR"
		rm -rf "$WEBROOT"/* || true
		cp -a "$SRC_DIR/." "$WEBROOT/"
		# Ensure files are readable and directories executable so nginx can access them
		chmod -R a+rX "$WEBROOT" || true
	else
		echo "[entrypoint] $WEBROOT already contains files; skipping copy from image source"
	fi
else
	echo "[entrypoint] Warning: source dir $SRC_DIR not found in image"
fi

# Remove only the default nginx index (if present) to avoid clobbering a
# legitimate `index.html` provided by the site source or by a bind mount.
if [ -f "$WEBROOT/index.html" ]; then
	if grep -q "Welcome to nginx" "$WEBROOT/index.html" 2>/dev/null; then
		rm -f "$WEBROOT/index.html" || true
	fi
fi

# TLS auto-generation: if no certificate/key exist at /etc/nginx/ssl, create
# a self-signed certificate for localhost so HTTPS works out-of-the-box for
# development. Do not overwrite files if the user mounted their own certs.
SSL_DIR=/etc/nginx/ssl
CRT_FILE="$SSL_DIR/server.crt"
KEY_FILE="$SSL_DIR/server.key"

if [ ! -f "$CRT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
	echo "[entrypoint] No TLS cert found at $SSL_DIR — generating self-signed cert"
	mkdir -p "$SSL_DIR"
	# Generate a 2048-bit RSA self-signed certificate valid 365 days for CN=localhost
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout "$KEY_FILE" -out "$CRT_FILE" \
		-subj "/CN=localhost" 2>/dev/null || {
			echo "[entrypoint] openssl failed to generate certs"
	}
	chmod 644 "$CRT_FILE" || true
	chmod 600 "$KEY_FILE" || true
else
	echo "[entrypoint] Found existing TLS certs in $SSL_DIR; not overwriting"
fi

# Compatibility: some nginx configs or older images reference /etc/nginx/html
# as the webroot. Create a symlink if that path doesn't exist so files are
# reachable regardless of which root nginx uses.
if [ ! -e "/etc/nginx/html" ]; then
	echo "[entrypoint] Creating compatibility symlink /etc/nginx/html -> $WEBROOT"
	mkdir -p "/etc/nginx"
	ln -s "$WEBROOT" "/etc/nginx/html" || true
else
	echo "[entrypoint] /etc/nginx/html already exists; leaving as-is"
fi

echo "[entrypoint] Starting: $@"

exec "$@"
