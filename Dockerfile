# Multi-arch Dockerfile leveraging pre-packaged Linux releases

FROM alpine:latest AS builder

ARG TARGETARCH

RUN apk add --no-cache ca-certificates curl tar

WORKDIR /tmp/build

COPY . /tmp/repo/

RUN set -e; \
    ARCH_SUFFIX=""; \
    if [ "$TARGETARCH" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then \
        ARCH_SUFFIX="linux-aarch64"; \
    else \
        ARCH_SUFFIX="linux-x86_64"; \
    fi; \
    mkdir -p /app /tmp/extract; \
    TAR_PATH="/tmp/repo/dist/pencarimovie-downloader-${ARCH_SUFFIX}.tar.gz"; \
    if [ -f "$TAR_PATH" ]; then \
        echo "Extracting local release package: $TAR_PATH"; \
        tar -xzf "$TAR_PATH" --strip-components=1 -C /tmp/extract 2>/dev/null || tar -xzf "$TAR_PATH" -C /tmp/extract; \
    elif [ -f "/tmp/repo/backend.php" ] && [ -x "/tmp/repo/bin/frankenphp" ] && [ -d "/tmp/repo/vendor" ]; then \
        echo "Copying workspace files directly..."; \
        cp -r /tmp/repo/public /tmp/repo/backend.php /tmp/repo/index.php /tmp/repo/router.php /tmp/repo/Caddyfile /tmp/extract/ 2>/dev/null || true; \
        cp -r /tmp/repo/vendor /tmp/extract/; \
        if [ -d "/tmp/repo/src" ]; then cp -r /tmp/repo/src /tmp/extract/; fi; \
        mkdir -p /tmp/extract/bin; \
        cp /tmp/repo/bin/php /tmp/extract/bin/php 2>/dev/null || true; \
        cp /tmp/repo/bin/php.ini.unix /tmp/extract/bin/php.ini 2>/dev/null || true; \
        cp /tmp/repo/bin/frankenphp /tmp/extract/bin/frankenphp 2>/dev/null || true; \
    else \
        echo "Downloading runtime package from GitHub..."; \
        curl -fsSL -o /tmp/server.tar.gz "https://github.com/aiskendi/pencarimovie-server/releases/latest/download/pencarimovie-downloader-${ARCH_SUFFIX}.tar.gz"; \
        tar -xzf /tmp/server.tar.gz --strip-components=1 -C /tmp/extract; \
        rm -f /tmp/server.tar.gz; \
    fi; \
    echo "Overlaying repository files..."; \
    cp -r /tmp/repo/public /tmp/repo/backend.php /tmp/repo/index.php /tmp/repo/router.php /tmp/repo/Caddyfile /tmp/extract/ 2>/dev/null || true; \
    if [ -f "/tmp/repo/.release-tag" ]; then cp /tmp/repo/.release-tag /tmp/extract/.release-tag; fi; \
    if [ -d "/tmp/repo/vendor" ]; then cp -r /tmp/repo/vendor /tmp/extract/; fi; \
    if [ -d "/tmp/repo/src" ]; then cp -r /tmp/repo/src /tmp/extract/; fi; \
    if [ -f "/tmp/repo/bin/php.ini.unix" ]; then cp /tmp/repo/bin/php.ini.unix /tmp/extract/bin/php.ini 2>/dev/null || true; fi; \
    if [ -f "/tmp/repo/bin/php" ]; then cp /tmp/repo/bin/php /tmp/extract/bin/php 2>/dev/null || true; fi; \
    cp -a /tmp/extract/. /app/; \
    mkdir -p /app/storage /tmp/caddy/data /tmp/caddy/config; \
    chmod -R 777 /app/storage; \
    chmod +x /app/bin/frankenphp /app/bin/php 2>/dev/null || true; \
    test -x /app/bin/frankenphp || (echo "FATAL: /app/bin/frankenphp is missing or not executable!" && exit 1)

FROM alpine:latest

RUN apk add --no-cache ca-certificates curl procps

WORKDIR /app

COPY --from=builder /app /app

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV PATH="/app/bin:$PATH"
ENV PHP_BINDIR="/app/bin"
ENV PHPRC="/app/bin"

EXPOSE 8088

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["start"]
