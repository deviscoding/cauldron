# syntax=docker/dockerfile:1.4
FROM stage-base as builder-gh
ARG UPSTREAM_VERSION=2.49.2
ARG TARGETARCH
ARG PACKAGES_GH='apt-utils'
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_arm64.deb /opt/
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_amd64.deb /opt/
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_amd64.tar.gz /opt/
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_arm64.tar.gz /opt/
RUN \
  ARCH="${TARGETARCH}" && \
  apt-get update && apt-get install -y --no-install-recommends $PACKAGES_GH /opt/gh_${UPSTREAM_VERSION}_linux_${ARCH}.deb && \
  tar --strip-components=1 -xzpf /opt/gh_${UPSTREAM_VERSION}_linux_${ARCH}.tar.gz -C "/tmp" && \
  cp -a /tmp/LICENSE "/usr/share/doc/gh" && \
  rm -R /tmp/* && \
  /usr/local/bin/license-handler "/usr/share/doc/gh/LICENSE" --source "${S6_URL}" --files "$S6_FILES" --output "/usr/share/doc/gh/copyright"

FROM scratch
COPY --chmod=755 --from=builder-gh /usr/bin/gh /usr/bin/gh
COPY --from=builder-gh /usr/share/doc/gh /usr/share/doc/gh