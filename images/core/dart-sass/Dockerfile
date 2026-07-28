# syntax=docker/dockerfile:1.4
FROM stage-base AS builder-sass
ARG UPSTREAM_VERSION
ARG TARGETARCH
ARG SASS_LICENSE="/opt/dart-sass/usr/local/bin/src/LICENSE"
ARG SASS_FILES="/usr/local/bin/sass /usr/local/bin/sass/src/dart /usr/local/bin/sass/src/sass.snapshot"
ARG SASS_DOC="/opt/dart-sass/usr/local/share/doc/dart-sass"
ADD https://github.com/sass/dart-sass/releases/download/${UPSTREAM_VERSION}/dart-sass-${UPSTREAM_VERSION}-linux-x64.tar.gz /opt/
ADD https://github.com/sass/dart-sass/releases/download/${UPSTREAM_VERSION}/dart-sass-${UPSTREAM_VERSION}-linux-arm64.tar.gz /opt/
RUN \
  ARCH="${TARGETARCH}" \
  && if [ "${ARCH}" = "amd64" ]; then ARCH="x64"; fi \
  && mkdir -p "/opt/dart-sass/usr/local/bin/" \
  && tar -C "/opt/dart-sass/usr/local/bin" -xzvf "/opt/dart-sass-${UPSTREAM_VERSION}-linux-${ARCH}.tar.gz" --strip-components=1 \
  && /usr/local/sbin/vat-config --prefix /opt/dart-sass --exec sass \
  && mkdir -p "$SASS_DOC" \
  && mv "$SASS_LICENSE" "$SASS_DOC/" \
  && /usr/local/sbin/license-handler "$SASS_DOC/LICENSE" \
  --source https://github.com/sass/dart-sass --files "$SASS_FILES" --output "$SASS_DOC/copyright"

FROM scratch
COPY --from=builder-sass /opt/dart-sass /
