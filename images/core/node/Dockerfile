# syntax=docker/dockerfile:1.4
FROM builder-node AS builder-node

FROM stage-base AS license-builder
ARG YARN_URL="https://github.com/yarnpkg/yarn"
COPY --chmod=755 extract-node-license /usr/local/sbin/
COPY --from=builder-node /usr/local/LICENSE /usr/local/share/doc/nodejs/LICENSE
COPY --from=builder-node /opt /opt/node
RUN \
  /usr/local/sbin/vat-config --prefix /opt/node --exec yarn node npm && \
  mkdir -p "/usr/local/share/doc/yarn" && \
  ln -s "$(find /opt/node -type f -name LICENSE -print -quit)" /usr/local/share/doc/yarn/LICENSE && \
  /usr/local/sbin/extract-node-license "/usr/local/share/doc/nodejs/LICENSE" "/usr/local/share/doc" && \
  /usr/local/sbin/license-handler "/usr/local/share/doc/yarn/LICENSE" --source "$YARN_URL" \
    --files "/usr/local/bin/yarn" --output "/usr/local/share/doc/yarn/copyright"

FROM scratch
COPY --from=license-builder /opt/node /opt/
COPY --from=builder-node /usr/local/bin /usr/local/bin
COPY --from=builder-node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=license-builder /usr/local/share/doc/nodejs /usr/local/share/doc/nodejs
COPY --from=license-builder /usr/local/share/doc/yarn /usr/local/share/doc/yarn

