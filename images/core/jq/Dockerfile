# syntax=docker/dockerfile:1.4
ARG UPSTREAM_VERSION
FROM ghcr.io/jqlang/jq:$UPSTREAM_VERSION AS jqlang-jq

# Builder
FROM stage-base AS builder-jq
ARG JQ_URL="https://github.com/jqlang/jq"
COPY --chmod=755 --from=jqlang-jq /jq "/opt/jq/usr/local/bin/jq"
COPY --chmod=777 --from=jqlang-jq /COPYING "/opt/jq/licenses/jq/COPYING"
COPY --chmod=777 --from=jqlang-jq /AUTHORS "/opt/jq/licenses/jq/AUTHORS"
RUN \
    vat-config --prefix /opt/jq --exec jq && \
    mkdir -p "/opt/jq/usr/local/share/doc/jq" && \
    /usr/local/sbin/license-handler "/opt/jq/licenses/jq/COPYING" --source "$JQ_URL" \
      --files "/usr/local/bin/jq" --output "/opt/jq/usr/local/share/doc/jq/copyright"
  
FROM scratch
# Forces BuildKit to keep "stage-base" alive.
ARG BASE_STAGE=builder-jq
COPY --from=builder-jq /opt/jq/ /
