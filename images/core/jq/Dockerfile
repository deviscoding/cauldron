# syntax=docker/dockerfile:1.4
FROM ghcr.io/jqlang/jq:latest AS jqlang-jq
ARG JQ_URL="https://github.com/jqlang/jq"

# Builder
FROM stage-base as builder-jq
COPY --chmod=755 --from=jqlang-jq /jq "/opt/jq/usr/local/bin/jq"
COPY --chmod=777 --from=jqlang-jq /COPYING "/opt/jq/licenses/jq/COPYING"
COPY --chmod=777 --from=jqlang-jq /AUTHORS "/opt/jq/licenses/jq/AUTHORS"
RUN mkdir -p "/opt/jq/usr/local/share/doc/jq" && \
  /usr/local/bin/license-handler "/opt/jq/licenses/jq/COPYING" -source "$JQ_URL" \
  --files "/usr/local/bin/jq" --output "/opt/jq/usr/local/share/doc/jq/copyright"
  
FROM scratch
COPY --from=builder-jq /opt/jq/ /
