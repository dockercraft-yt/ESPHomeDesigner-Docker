# ESPHomeDesigner-Docker

Simple Docker packaging for the ESPHome Designer client-side editor.

Build and run (recommended):

```bash
# Build using the `Docker/` directory as build context (recommended)
docker build -t esphome-designer Docker

# Run the container and expose on localhost:8080
docker run --rm -p 8080:80 esphome-designer
```

Alternative: build from repository root as context. If you do this, use
`-f Docker/Dockerfile` and note that `COPY` paths in the Dockerfile are
context-relative:

```bash
docker build -t esphome-designer -f Docker/Dockerfile .
```

Live-editing (no rebuild): mount the local `Docker/src/data` into the
container's nginx webroot. This is useful for quick UI changes during
development:

```bash
docker run --rm -p 8080:80 \
	-v "$(pwd)/Docker/src/data":/usr/share/nginx/html:ro \
	esphome-designer
```

Entrypoint behavior and notes for contributors:

- The image includes an `entrypoint.sh` that copies the bundled site from
	`/opt/site_src` into `/usr/share/nginx/html` at container start if the
	webroot looks empty or contains the default nginx welcome files. This
	preserves user bind mounts at `/usr/share/nginx/html` so local live-edit
	mounts are not overwritten.
- The frontend is a static single-page app; primary files of interest are
	`Docker/src/data/editor.html`, `Docker/src/data/js/main.js`, and
	`Docker/src/data/feature_registry.js`. Widgets live in
	`Docker/src/data/features/{featureId}/render.js`.

Quick local development without Docker:

```bash
# Serve the static files directly (npm `http-server` or similar)
npx http-server Docker/src/data -p 8080
# Then open http://localhost:8080
```

If you want this README expanded with examples for adding a new feature
module or debugging dynamic imports, tell me which section you want added.

HTTPS / TLS notes

- The image ships with an nginx configuration that redirects HTTP to HTTPS
	and expects TLS files at `/etc/nginx/ssl/server.crt` and
	`/etc/nginx/ssl/server.key` inside the container. You can provide certs
	in two ways:

	1. Mount existing certs into the container:

```bash
docker run --rm -p 8443:443 \
	-v "$(pwd)/certs/server.crt":/etc/nginx/ssl/server.crt:ro \
	-v "$(pwd)/certs/server.key":/etc/nginx/ssl/server.key:ro \
	esphome-designer
```

	2. Generate a self-signed certificate locally for testing:

```bash
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout certs/server.key -out certs/server.crt \
	-subj "/CN=localhost"

docker run --rm -p 8443:443 \
	-v "$(pwd)/certs/server.crt":/etc/nginx/ssl/server.crt:ro \
	-v "$(pwd)/certs/server.key":/etc/nginx/ssl/server.key:ro \
	esphome-designer
```

Then open https://localhost:8443 in your browser (you may need to accept a
browser warning for self-signed certs).

Auto-generated certificates

- The container will auto-generate a self-signed certificate at startup if
	no files exist at `/etc/nginx/ssl/server.crt` and
	`/etc/nginx/ssl/server.key`. The generated cert is a 2048-bit RSA cert
	for `CN=localhost` and is valid for 365 days. The entrypoint will NOT
	overwrite certs if you mount your own files into `/etc/nginx/ssl`.

- If you need Subject Alternative Names (SANs) (recommended for modern
	browsers), generate the cert locally and mount it into the container.
	Example using OpenSSL (works with recent OpenSSL versions that support
	`-addext`):

```bash
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout certs/server.key -out certs/server.crt \
	-subj "/CN=localhost" \
	-addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

docker run --rm -p 8443:443 \
	-v "$(pwd)/certs/server.crt":/etc/nginx/ssl/server.crt:ro \
	-v "$(pwd)/certs/server.key":/etc/nginx/ssl/server.key:ro \
	esphome-designer
```

If your OpenSSL doesn't support `-addext`, create a small OpenSSL config
file with an `[ alt_names ]` section and pass it with `-extensions v3_req`
— I can provide that example if you need it.

Notable runtime details (what changed)

- `entrypoint.sh` now copies the bundled site from `/opt/site_src` into
	nginx's webroot at `/usr/share/nginx/html` at container start. This makes
	the image friendly to bind-mounts and live-edit workflows: if you mount
	your local `Docker/src/data` into `/usr/share/nginx/html`, the entrypoint
	will preserve it instead of overwriting.
- The entrypoint also auto-generates a self-signed TLS certificate at
	`/etc/nginx/ssl/server.crt` and `/etc/nginx/ssl/server.key` when none are
	provided. If you mount your own certs into that path they will not be
	overwritten.
- The nginx config (`Docker/src/nginx/default.conf`) is reverse-proxy
	friendly: it checks `X-Forwarded-Proto` so an external proxy that
	terminates TLS can forward requests to the container without triggering
	an extra redirect, and it provides an SPA fallback (`editor.html`) so
	path-based proxying works correctly.

These notes are intended to help contributors and operators understand the
runtime behavior without digging through the entrypoint and nginx files.

**Remote Image (downloads frontend at startup)**

- **Purpose**: The remote variant downloads the frontend assets from the
	public GitHub repo at container start, extracts them, and populates
	nginx's webroot. This avoids bundling the UI into the image at build
	time and is useful for CI-free deployments or quick testing of the
	upstream repository.
- **Files**: See [Docker/remote_Dockerfile](Docker/remote_Dockerfile) and
	[Docker/remote_entrypoint.sh](Docker/remote_entrypoint.sh).
- **Preferred source path**: the entrypoint prefers
	`custom_components/reterminal_dashboard/frontend` inside the repo ZIP and
	falls back to `Docker/src/data` when the preferred path isn't present.

Build and run the remote image:

```bash
docker build -t esphome-designer-remote -f Docker/remote_Dockerfile .
docker run --rm -p 8080:80 -p 8443:443 esphome-designer-remote
```


**Environment variables for TLS & entrypoint**

- **CERT_AUTOGEN**: `1` (default) — auto-generate a self-signed cert when
	no certs are present; set to `0` or `false` to disable auto-generation.

Mount your own TLS files into `/etc/nginx/ssl/server.crt` and
`/etc/nginx/ssl/server.key` to use production certs; the entrypoint will
not overwrite mounted files.

If you want these docs moved into a short `docs/` file or expanded with
examples for generating SAN certs on various platforms, tell me and I
will add it.
