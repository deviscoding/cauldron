# syntax=docker/dockerfile:1.4
FROM stage-base AS builder-gh
ARG UPSTREAM_VERSION=2.49.2
ARG TARGETARCH
ARG GH_PACKAGES='apt-utils'
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_arm64.deb /opt/
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_amd64.deb /opt/
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_amd64.tar.gz /opt/
ADD https://github.com/cli/cli/releases/download/v${UPSTREAM_VERSION}/gh_${UPSTREAM_VERSION}_linux_arm64.tar.gz /opt/
RUN \
  ARCH="${TARGETARCH}" && \
  apt-get update && apt-get install -y --no-install-recommends $GH_PACKAGES /opt/gh_${UPSTREAM_VERSION}_linux_${ARCH}.deb && \
  /usr/local/sbin/vat-config --exec "gh"  && \
  tar --strip-components=1 -xzpf /opt/gh_${UPSTREAM_VERSION}_linux_${ARCH}.tar.gz -C "/tmp" && \
  mkdir -p "/usr/share/doc/gh" && \
  cp -a /tmp/LICENSE "/usr/share/doc/gh/LICENSE" && \
  cp -a /tmp/share/man "/usr/share/man" && \
  rm -R /tmp/* && \
  /usr/local/sbin/license-handler "/usr/share/doc/gh/LICENSE" --source "https://github.com/cli/cli" --files "/usr/bin/gh" --output "/usr/share/doc/gh/copyright"

FROM scratch
COPY --chmod=755 --from=builder-gh /usr/bin/gh /usr/local/bin/gh
COPY --from=builder-gh /usr/share/man/* /usr/share/man/
COPY --from=builder-gh /usr/share/doc/gh /usr/share/doc/gh
COPY --from=builder-gh /etc/vat/exec.d/gh /etc/vat/exec.d/gh