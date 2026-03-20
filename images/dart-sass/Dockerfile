# syntax=docker/dockerfile:1.4
FROM stage-base as builder-sass
ARG UPSTREAM_VERSION=1.77.1
ARG TARGETARCH
ARG SASS_DIR="/opt/dart-sass"
ARG SASS_LICENSE="${SASS_DIR}/usr/bin/src/LICENSE"
ARG SASS_FILES="/usr/bin/sass /usr/bin/sass/src/dart /usr/bin/sass/src/sass.snapshot"
ARG SASS_DOC="${SASS_DIR}/usr/share/doc/dart-sass"
ADD https://github.com/sass/dart-sass/releases/download/${UPSTREAM_VERSION}/dart-sass-${UPSTREAM_VERSION}-linux-x64.tar.gz /opt/
ADD https://github.com/sass/dart-sass/releases/download/${UPSTREAM_VERSION}/dart-sass-${UPSTREAM_VERSION}-linux-arm64.tar.gz /opt/
RUN \
  ARCH="${TARGETARCH}" \
  && if [ "${ARCH}" = "amd64" ]; then ARCH="x64"; fi \
  && mkdir -p "$SASS_DIR/usr/bin/" \
  && tar -C "$SASS_DIR/usr/bin" -xzvf "/opt/dart-sass-${UPSTREAM_VERSION}-linux-${ARCH}.tar.gz" --strip-components=1 \
  && mkdir -p "$SASS_DOC" \
  && mv "$SASS_DIR/usr/bin/src/LICENSE" "$SASS_DOC/" \
  && /usr/local/bin/license-handler "$SASS_DOC/LICENSE" \
  --source https://github.com/sass/dart-sass --files "$SASS_FILES" --output "$SASS_DOC/copyright"

FROM scratch
COPY --from=builder-sass /opt/dart-sass /

