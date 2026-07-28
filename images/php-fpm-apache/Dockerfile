# syntax=docker/dockerfile:1.4
ARG PHP_VERSION
ARG OS_VERSION
FROM stage-base

ARG PACKAGES
ARG PHP_EXTENSIONS
ARG PHP_EXT_INSTALLER_VERSION
ARG COMPOSER_VERSION
ARG HEALTHCHECK_SILENCE

#
# Global Dependency Installation
#
RUN echo "### Base Layer for PHP Version: ${PHP_VERSION} ###" && \
    apt-get update && vat-apt-get install -y --no-install-recommends $PACKAGES && \
    rm -rf /tmp/* /var/tmp/* && \
    locale-gen en_US.UTF-8 en_US es_MX.UTF-8 es_MX

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/$PHP_EXT_INSTALLER_VERSION/install-php-extensions /usr/local/bin/
ADD --chmod=0755 https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/v0.5.0/php-fpm-healthcheck /usr/local/bin/

RUN IPE_GD_WITHOUTAVIF=1 install-php-extensions ${PHP_EXTENSIONS}

#
# Apache Configuration
#

ENV APACHE_CONFDIR=/etc/apache2
ENV APACHE_ENVVARS="${APACHE_CONFDIR}/envvars"
ENV APACHE_DOCUMENT_ROOT=/var/www/html \
    APACHE_START_SERVERS="2" \
    APACHE_MIN_SPARE_THREADS="10" \
    APACHE_MAX_SPARE_THREADS="75" \
    APACHE_THREAD_LIMIT="64" \
    APACHE_THREADS_PER_CHILD="25" \
    APACHE_MAX_REQUEST_WORKERS="150" \
    APACHE_MAX_CONNECTIONS_PER_CHILD="0" \
    APACHE_RUN_USER="www-data" \
    APACHE_RUN_GROUP="www-data" \
    APACHE_HTTP=8080 \
    APACHE_HTTPS=8443

    # These are for reference to apps only; they are the external ports for the container, not internal ones!
ENV COMPOSE_HTTP=8080 \
    COMPOSE_HTTPS=8443 \
    COMPOSE_HOST="localhost"

# Copy utilities & configuration profiles
COPY --from=apache etc/apache2/conf-available/docker-php.conf "${APACHE_CONFDIR}/conf-available/docker-php.conf"
COPY --from=apache etc/apache2/conf-available/docker-dev.conf "${APACHE_CONFDIR}/conf-available/docker-dev.conf"
COPY --from=apache etc/apache2/conf-available/docker-mpm-event.conf "${APACHE_CONFDIR}/conf-available/docker-mpm-event.conf"
COPY --from=apache etc/apache2/ports.conf "${APACHE_CONFDIR}/ports.conf"

# Apache Startup Files
COPY --from=apache --chmod=755 ./vat-apache.sh /usr/local/sbin/vat-apache
COPY --from=apache --chmod=755 ./usr/local/sbin/vat-suggest-config.sh /usr/local/sbin/vat-suggest-config
COPY --from=apache --chmod=755 vat-entrypoint.sh /usr/bin/vat-entrypoint
COPY --from=apache ./etc/s6-overlay/ /etc/s6-overlay/

RUN a2enmod actions autoindex deflate expires headers http2 proxy proxy_http proxy_fcgi remoteip rewrite setenvif ssl unique_id vhost_alias && \
    chown -R www-data:www-data /var/www /etc/apache2 && chmod -R 755 /var/www && \
    /usr/local/sbin/vat-apache

#
# PHP Configuration
#

ENV PHP_DATE_TIMEZONE="America/Chicago" \
    PHP_DISPLAY_ERRORS=Off \
    PHP_DISPLAY_STARTUP_ERRORS=Off \
    PHP_ERROR_LOG="/dev/stderr" \
    PHP_ERROR_REPORTING="22527" \
    PHP_FPM_PM_CONTROL=dynamic \
    PHP_FPM_PM_MAX_CHILDREN="20" \
    PHP_FPM_PM_MAX_SPARE_SERVERS="3" \
    PHP_FPM_PM_MIN_SPARE_SERVERS="1" \
    PHP_FPM_PM_START_SERVERS="2" \
    PHP_FPM_PROCESS_CONTROL_TIMEOUT="10s" \
    PHP_MAX_EXECUTION_TIME="99" \
    PHP_MAX_INPUT_TIME="-1" \
    PHP_MAX_INPUT_VARS="10000" \
    PHP_MEMORY_LIMIT="1024M" \
    PHP_OPCACHE_ENABLE="1" \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER="8" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="20000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="256" \
    PHP_OPCACHE_REVALIDATE_FREQ="2" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="1" \
    PHP_POST_MAX_SIZE="100M" \
    PHP_REALPATH_CACHE_SIZE=4096K \
    PHP_REALPATH_CACHE_TTL=600 \
    PHP_SESSION_COOKIE_SECURE=false \
    PHP_UPLOAD_MAX_FILE_SIZE="100M"

COPY etc/s6-overlay/ /etc/s6-overlay/
COPY --from=php usr/local/etc/php/php.ini /usr/local/etc/php/
COPY usr/local/etc/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY usr/local/etc/php-fpm.d/zz-silence-health-${HEALTHCHECK_SILENCE}.conf /usr/local/etc/php-fpm.d/zz-silence-health.conf
RUN chown www-data:www-data /usr/local/etc/php/php.ini /usr/local/etc/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-silence-health.conf

#
# Composer & PHP Tools
#

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/var/www/.composer \
    COMPOSER_MAX_PARALLEL_HTTP=24

COPY --from=stage-composer --chmod=755 /usr/bin/composer /usr/local/bin/composer
RUN mkdir -p "$COMPOSER_HOME" && chown -R www-data:www-data "${COMPOSER_HOME}"

#
# Final Steps
#

ENV APP_DIR=/var/www \
    APP_ENV="prod" \
    APP_DEBUG=0 \
    HEALTHCHECK_PATH="/healthcheck" \
    LOG_LEVEL=warn \
    S6_ROOTLESS=1

USER www-data
WORKDIR $APP_DIR
EXPOSE 8080 8443
ENTRYPOINT ["vat-entrypoint"]
STOPSIGNAL SIGQUIT
CMD ["/init"]

HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
    CMD [ "sh", "-c", "curl --insecure --silent --location --show-error --fail http://localhost:${APACHE_HTTP}${HEALTHCHECK_PATH} || exit 1" ]
