# syntax=docker/dockerfile:1.4
ARG OS_VERSION
ARG PHP_VERSION
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${OS_VERSION}"

# Base Image for PHP FPM + Apac
FROM ${BASE_IMAGE}
ARG OS_VERSION
ENV PATH="/usr/local/sbin:/usr/local/bin:${PATH}"
COPY --chmod=755 fix-debian-sources /usr/local/sbin/fix-sources
COPY --chmod=755 --from=common ./vat-env /usr/local/sbin/vat-env
COPY --chmod=755 --from=common ./vat-pkg-copy /usr/local/sbin/vat-pkg-copy
COPY --chmod=755 --from=common ./license-handler /usr/local/sbin/license-handler
RUN fix-debian-sources "${OS_VERSION}" && rm /usr/local/sbin/fix-debian-sources && \
    mkdir -p /usr/share/man/man1 && \
    apt-get update && apt-get install -y --no-install-recommends licensecheck && \
    rm -rf /tmp/* /var/tmp/*