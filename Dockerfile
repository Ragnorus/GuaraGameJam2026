# Stage 1: export the Godot project to a web (HTML5) build.
FROM debian:bookworm-slim AS export

ARG GODOT_VERSION=4.5.1
ENV GODOT_VERSION=${GODOT_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && curl -fsSL -o /tmp/templates.tpz \
        "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
    && unzip -q /tmp/templates.tpz -d /tmp/templates \
    && mv /tmp/templates/templates/* "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable/" \
    && rm -rf /tmp/godot.zip /tmp/templates.tpz /tmp/templates

WORKDIR /project
COPY . .
RUN mkdir -p build/web \
    && godot --headless --import || true \
    && godot --headless --export-release "Web" build/web/index.html \
    && test -f build/web/index.html

# Stage 2: serve the static export. Railway provides $PORT at runtime.
FROM nginx:alpine
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=export /project/build/web /usr/share/nginx/html
ENV PORT=8080
EXPOSE 8080
