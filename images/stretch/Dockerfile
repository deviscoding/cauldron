# syntax=docker/dockerfile:1.4
ARG BASE_OS_VERSION='stretch'
ARG PHP_VERSION='7.0.33'
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${BASE_OS_VERSION}"

# LicenseCheck
FROM ${BASE_IMAGE} AS stage-license-check
COPY --chmod=755 fix-debian-stretch-sources /usr/local/bin/fix-debian-stretch-sources
RUN /usr/local/bin/fix-debian-stretch-sources && rm /usr/local/bin/fix-debian-stretch-sources && \
    apt-get update && apt-get install -y licensecheck

# Builder
FROM ${BASE_IMAGE}
COPY --chmod=755 fix-debian-stretch-sources /usr/local/bin/fix-debian-stretch-sources
COPY --chmod=755 --from=common ./cauldron-env /usr/local/bin/cauldron-env
COPY --chmod=755 --from=common ./cauldron-pkg-copy /usr/local/bin/cauldron-pkg-copy
COPY --chmod=755 --from=common ./license-handler /usr/local/bin/license-handler
COPY --from=stage-license-check --chmod=755 /usr/bin/licensecheck /usr/bin/licensecheck
COPY --from=stage-license-check /usr/share/perl5/ /usr/share/perl5/
COPY --from=stage-license-check /usr/share/doc/licensecheck/ /usr/share/doc/licensecheck/
RUN /usr/local/bin/fix-debian-stretch-sources && rm /usr/local/bin/fix-debian-stretch-sources && \
    mkdir -p /usr/share/man/man1