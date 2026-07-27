# syntax=docker/dockerfile:1.4
ARG OS_VERSION
ARG PHP_VERSION
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${OS_VERSION}"

# Base Image for PHP FPM + Apac
FROM ${BASE_IMAGE}
ARG OS_VERSION
ENV PATH="/usr/local/sbin:/usr/local/bin:${PATH}"
COPY --chmod=755 fix-debian-sources.sh /usr/local/sbin/fix-debian-sources
COPY --chmod=755 --from=common ./vat-env.sh /usr/local/sbin/vat-env
COPY --chmod=755 --from=common ./vat-pkg-copy.sh /usr/local/sbin/vat-pkg-copy
COPY --chmod=755 --from=common ./license-handler.sh /usr/local/sbin/license-handler
RUN fix-debian-sources "${OS_VERSION}" && rm /usr/local/sbin/fix-debian-sources && \
    mkdir -p /usr/share/man/man1 && \
    apt-get update && apt-get install -y --no-install-recommends licensecheck && \
    rm -rf /tmp/* /var/tmp/*