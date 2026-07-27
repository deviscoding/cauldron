# syntax=docker/dockerfile:1.4
ARG OS_VERSION
ARG PHP_VERSION
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${OS_VERSION}"

# Base Image for PHP FPM + Apac
FROM ${BASE_IMAGE}
ARG OS_VERSION
ENV BASH_ENV="/etc/profile.d/vat-env"
ENV ENV="/etc/profile.d/vat-env"
ENV VAT_ENV_DIR="/etc/vat/env.d"
ENV VAT_EXEC_DIR="/etc/vat/exec.d"
ENV PATH="/usr/local/sbin:/usr/local/bin:${PATH}"
COPY --chmod=755 fix-debian-sources.sh /usr/local/sbin/fix-debian-sources
COPY --chmod=755 --from=common ./vat-config.sh /usr/local/sbin/vat-config
COPY --chmod=755 --from=common ./vat-env.sh /etc/profile.d/vat-env
COPY --chmod=755 --from=common ./vat-pkg-copy.sh /usr/local/sbin/vat-pkg-copy
COPY --chmod=755 --from=common ./license-handler.sh /usr/local/sbin/license-handler
RUN fix-debian-sources "${OS_VERSION}" && rm /usr/local/sbin/fix-debian-sources && \
    mkdir -p /usr/share/man/man1 && vat-config --init && \
    apt-get update && apt-get install -y --no-install-recommends licensecheck && \
    rm -rf /tmp/* /var/tmp/*