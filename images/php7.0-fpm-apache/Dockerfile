# syntax=docker/dockerfile:1.4
FROM stage-base
ENV APACHE_CONFDIR=/etc/apache2
ENV APACHE_ENVVARS="${APACHE_CONFDIR}/envvars"

ARG S6_DIR='/opt/s6'
ARG PACKAGES_APACHE='libfcgi-bin apache2 locales procps git zip openssh-client jq'
ARG PHP_EXTENSIONS='mysqli opcache pcntl pdo_mysql zip bcmath intl ldap soap mcrypt apcu calendar exif gd imagick sodium'
ARG REPOSITORY_BUILD_VERSION='dev'
ARG PHP_EXT_INSTALLER_VERSION='2.7.0'
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
    APP_BASE_DIR=/var/www/html \
    CONTAINER_ENV="prod" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    COMPOSER_MAX_PARALLEL_HTTP=24 \
    DISABLE_DEFAULT_CONFIG=false \
    HEALTHCHECK_PATH="/healthcheck" \
    LOG_OUTPUT_LEVEL=warn \
    PHP_DATE_TIMEZONE="America/Chicago" \
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
    PHP_UPLOAD_MAX_FILE_SIZE="100M" \
    SHOW_WELCOME_MESSAGE=true

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/$PHP_EXT_INSTALLER_VERSION/install-php-extensions /usr/local/bin/
ADD --chmod=0755 https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/v0.5.0/php-fpm-healthcheck /usr/local/bin/

# These are copied into temporary paths, and must be moved after apache is installed
COPY --from=apache etc/apache2/conf-available/docker-php.conf "/var/www/docker-php.conf"
COPY --from=apache etc/apache2/conf-available/docker-dev.conf "/var/www/docker-dev.conf"
COPY --from=apache etc/apache2/conf-available/docker-mpm-event.conf "/var/www/docker-mpm-event.conf"

# Copy php.ini and php-fpm config
COPY --from=common usr/local/etc/php/php.ini /usr/local/etc/php/
COPY --from=common usr/local/etc/php-fpm.d/xx-docker.conf /usr/local/etc/php-fpm.d/
COPY usr/local/etc/php-fpm.d/zz-silence-health.conf /usr/local/etc/php-fpm.d/

# Copy Configuration Utility
COPY --chmod=0755 --from=apache ./usr/local/sbin/suggest-config /usr/local/sbin/suggest-config

# apache, other dependencies, pecl extensions, and clean up
RUN echo "Installing: $PACKAGES_APACHE" && \
    apt-get update && apt-get install -y $PACKAGES_APACHE && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    \
    # generate locales we will likely use \
    locale-gen en_US.UTF-8 && locale-gen en_US && \
    locale-gen es_MX.UTF-8 && locale-gen es_MX && \
    \
    # Ensure /var/www/ has the correct permissions \
    chown -R www-data:www-data /var/www && \
    chmod -R 755 /var/www && \
    \
    # Install default PHP extensions \
    IPE_GD_WITHOUTAVIF=1 install-php-extensions ${PHP_EXTENSIONS}

RUN \
    echo "### ENABLE APACHE MODS ###" && \
    a2enmod actions autoindex deflate expires headers http2 proxy proxy_http proxy_fcgi remoteip rewrite setenvif ssl unique_id vhost_alias

# Apache Startup Files
COPY --chmod=755 docker-php-entrypoint /usr/local/bin/

# install composer from Composer's official Docker image (2.2 is max version for PHP 7.1)
COPY --from=composer:2.2 --chmod=755 /usr/bin/composer /usr/bin/composer

# Copy Dart Sass
COPY --from=stage-dart-sass / /

# Copy JQ
COPY --from=stage-jq / /

# Copy GH-CLI
COPY --from=stage-gh / /

# Copy S6 Overlay
COPY --from=stage-s6-overlay / /
COPY --from=apache ./etc/s6-overlay/ /etc/s6-overlay/

# Add Environment Variables & Correct Permissions
RUN echo "### CONFIGURING ENVIRONMENT VARIABLES ###" && \
    /usr/local/sbin/cauldron-env gh sass composer && \
    echo "### CORRECTING S6 PERMISSIONS ###" && \
    chmod 755 /etc/s6-overlay/s6-rc.d/*/run && \
    chmod 755 /etc/s6-overlay/s6-rc.d/*/data/check

ENTRYPOINT ["docker-php-entrypoint"]

# Set stop signal to SIGQUIT for a graceful shutdown
# (https://github.com/just-containers/s6-overlay/issues/586)
STOPSIGNAL SIGQUIT

WORKDIR ${APP_BASE_DIR}

EXPOSE 80 443

CMD ["/init"]

HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
    CMD [ "sh", "-c", "curl --insecure --silent --location --show-error --fail http://localhost:80$HEALTHCHECK_PATH || exit 1" ]