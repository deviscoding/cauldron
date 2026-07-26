# syntax=docker/dockerfile:1.4
ARG OS_VERSION
ARG PHP_VERSION
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${OS_VERSION}"

# LicenseCheck
FROM ${BASE_IMAGE} AS stage-license-check
ARG OS_VERSION
COPY --chmod=755 fix-debian-sources /usr/local/sbin/fix-debian-sources
RUN /usr/local/sbin/fix-debian-sources && rm /usr/local/sbin/fix-debian-sources "$OS_VERSION" && \
    apt-get update && apt-get install -y licensecheck

# Builder
FROM ${BASE_IMAGE}
ARG OS_VERSION
COPY --chmod=755 fix-debian-sources /usr/local/sbin/fix-sources
COPY --chmod=755 --from=common ./vat-env /usr/local/sbin/vat-env
COPY --chmod=755 --from=common ./vat-pkg-copy /usr/local/sbin/vat-pkg-copy
COPY --chmod=755 --from=common ./license-handler /usr/local/bin/license-handler
COPY --from=stage-license-check --chmod=755 /usr/bin/licensecheck /usr/bin/licensecheck
COPY --from=stage-license-check /usr/share/perl5/ /usr/share/perl5/
COPY --from=stage-license-check /usr/share/doc/licensecheck/ /usr/share/doc/licensecheck/
RUN /usr/local/sbin/fix-debian-sources && rm /usr/local/sbin/fix-debian-sources "$OS_VERSION" && \
    mkdir -p /usr/share/man/man1