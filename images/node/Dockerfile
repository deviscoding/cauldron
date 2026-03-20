# syntax=docker/dockerfile:1.4
ARG UPSTREAM_VERSION=24
ARG TARGETARCH
FROM node:${UPSTREAM_VERSION} as builder-node

FROM builder-base as license-builder
ARG YARN_URL="https://github.com/yarnpkg/yarn"
COPY --chmod 755 extract-node-license /usr/local/sbin/
COPY --from=builder-node /usr/local/LICENSE /usr/local/share/doc/nodejs/LICENSE
COPY --from=builder-node /opt /opt
RUN \
  ln -s "$(find /opt -type f -name LICENSE -print -quit)" /usr/local/share/doc/yarn/LICENSE && \
  /usr/local/sbin/extract-node-license "/usr/local/share/doc/node/LICENSE" "/usr/local/share/doc" && \
  /usr/local/bin/license-handler "/usr/local/share/doc/yarn/LICENSE" --source "$YARN_URL" \
    --files "/usr/local/bin/yarn" --output "/usr/local/share/doc/yarn/copyright"

FROM scratch
COPY --from=builder-node /opt /opt
COPY --from=builder-node /usr/local/bin /usr/local/bin
COPY --from=builder-node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=license-builder /usr/local/share/doc/node /usr/local/share/doc/node
COPY --from=license-builder /usr/local/share/doc/yarn /usr/local/share/doc/yarn

