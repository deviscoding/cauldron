# syntax=docker/dockerfile:1.4
ARG UPSTREAM_VERSION
FROM mikefarah/yq:${UPSTREAM_VERSION} AS mikefarah-yq
ARG TARGETARCH
ARG YQ_URL="https://github.com/mikefarah/yq"

FROM scratch
COPY --chmod=755 --from=mikefarah-yq /usr/bin/yq "/usr/local/bin/yq" 
COPY etc/vat/exec.d/yq /etc/vat/exec.d/yq