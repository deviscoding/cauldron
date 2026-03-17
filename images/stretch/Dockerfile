# syntax=docker/dockerfile:1.4
ARG BASE_OS_VERSION='stretch'
ARG PHP_VERSION='7.0.33'
ARG BASE_IMAGE="php:${PHP_VERSION}-fpm-${BASE_OS_VERSION}"

# Builder
FROM ${BASE_IMAGE}
COPY --chmod=755 fix-debian-stretch-sources /usr/local/bin/fix-debian-stretch-sources
RUN /usr/local/bin/fix-debian-stretch-sources && rm /usr/local/bin/fix-debian-stretch-sources && \
    mkdir -p /usr/share/man/man1