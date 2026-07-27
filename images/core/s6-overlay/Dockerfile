# syntax=docker/dockerfile:1.4
FROM stage-base as builder-s6
ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG S6_DIR='/opt/s6'
ARG S6_FILES="/etc/s6-overlay/* /init /bin/s6-*"
ARG S6_COPYRIGHT="${S6_DIR}/usr/share/doc/s6-overlay/copyright"
ARG S6_URL="https://github.com/just-containers/s6-overlay"
ADD ${S6_URL}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD ${S6_URL}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-aarch64.tar.xz /tmp
ADD ${S6_URL}/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
ADD ${S6_URL}/archive/refs/tags/v${S6_OVERLAY_VERSION}.tar.gz /tmp
RUN ARCH="${TARGETARCH}" && TARGET_DIR="${S6_DIR}" && TARGET_DOC="${TARGET_DIR}/usr/local/share/doc/s6-overlay" && \
    if [ "${ARCH}" = "amd64" ]; then ARCH="x86_64"; elif [ "${ARCH}" = "arm64" ]; then ARCH="aarch64"; fi; \
    mkdir -p "$TARGET_DIR" && \
    mkdir -p "${TARGET_DOC}" && \
    mkdir -p "${TARGET_DOC}" && \
    tar --strip-components=1 -Jxpf /tmp/s6-overlay-noarch.tar.xz -C "${TARGET_DIR}" && \
    tar --strip-components=1 -Jxpf "/tmp/s6-overlay-${ARCH}.tar.xz" -C "${TARGET_DIR}" && \
    tar --strip-components=1 -xzpf /tmp/v${S6_OVERLAY_VERSION}.tar.gz -C "/tmp" && \
    cp -a /tmp/COPYING "${TARGET_DOC}" && \
    rm -R /tmp/* && \
    /usr/local/bin/license-handler "${TARGET_DOC}/COPYING" --source "${S6_URL}" --files "$S6_FILES" --output "${TARGET_DOC}/copyright"

FROM scratch
COPY --from=common ./etc/s6-overlay/ /etc/s6-overlay/
COPY --from=builder-s6 /opt/s6 /