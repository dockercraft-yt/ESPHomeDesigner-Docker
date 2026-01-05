FROM nginx:latest

# Copy site source into a safe location in the image. At container start an
# entrypoint script will copy these files into nginx's webroot. This allows
# runtime overlays (bind mounts) or late copying behavior. Use build-context
# relative paths (the build context is the repository root when running
# `docker build -f Docker/Dockerfile .`).
COPY src/data/ /opt/site_src/

# Install our nginx config (index set to editor.html)
COPY src/nginx/default.conf /etc/nginx/conf.d/default.conf

# Add entrypoint that will copy files into /usr/share/nginx/html at runtime
# When building with the Docker context (recommended):
#   docker build -t esphome-designer Docker
# the paths below resolve to Docker/src/ and Docker/entrypoint.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Install openssl so the entrypoint can generate a self-signed certificate at runtime
RUN apt-get update \
	&& apt-get install -y --no-install-recommends openssl ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/entrypoint.sh"]
# Default command: run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]