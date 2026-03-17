# syntax=docker/dockerfile:1.4
ARG BASE_OS_VERSION='stretch'
ARG PHP_VERSION='7.0.33'
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${BASE_OS_VERSION}"

# LicenseCheck
FROM ${BASE_IMAGE} AS stage-license-check
RUN apt-get update && apt-get install -y licensecheck

# Builder
FROM ${BASE_IMAGE}
COPY --chmod=755 fix-debian-stretch-sources /usr/local/bin/fix-debian-stretch-sources
COPY --chmod=755 --from=common ./usr/local/sbin/license-handler /usr/local/sbin/license-handler
COPY --from=stage-license-check --chmod=755 /usr/bin/licensecheck /usr/bin/licensecheck
COPY --from=stage-license-check /usr/share/perl5/ /usr/share/perl5/
COPY --from=stage-license-check /usr/share/doc/licensecheck/ /usr/share/doc/licensecheck/
RUN /usr/local/bin/fix-debian-stretch-sources && rm /usr/local/bin/fix-debian-stretch-sources && \
    mkdir -p /usr/share/man/man1