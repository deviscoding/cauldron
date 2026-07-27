#!/bin/bash

echo "====== Start: FIXING APACHE DIRECTORIES ======"
chown -R "$APACHE_RUN_USER":"$APACHE_RUN_GROUP" "$APP_BASE_DIR"
# shellcheck source=./etc/apache2/envvars.default
. "$APACHE_ENVVARS"
for dir in "$APACHE_LOCK_DIR" "$APACHE_RUN_DIR" "$APACHE_RUN_DIR/socks"; do \
  rm -rvf "$dir"
    mkdir -p "$dir"
    chown "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"
    # allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
    chmod 1777 "$dir"
done;

mkdir -p "$APACHE_LOG_DIR"
chown -R --no-dereference "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APACHE_LOG_DIR"
chmod 1777 "$APACHE_LOG_DIR"
# delete the "index.html" that installing Apache drops in here
rm -rvf /var/www/html/*
echo "====== End: FIXING APACHE DIRECTORIES ======"

echo "====== Start: ALLOW ${APACHE_ENVVARS} EXPORT OVERRIDES & IMPORT ======"
sed -ri 's/^export ([^=]+)=(.*)$/export \1=${\1:-\2}/' "$APACHE_ENVVARS" || exit 1
echo "======   End: ALLOW ${APACHE_ENVVARS} EXPORT OVERRIDES & IMPORT ======"

echo "====== Start: ENABLE APACHE CONFIGS ======"
mv "/var/www/docker-php.conf" "$APACHE_CONFDIR/conf-available/docker-php.conf" && \
  mv "/var/www/docker-dev.conf" "$APACHE_CONFDIR/conf-available/docker-dev.conf" && \
  mv "/var/www/docker-mpm-event.conf" "$APACHE_CONFDIR/conf-available/docker-mpm-event.conf" && \
  a2enconf docker-php && \
  a2enconf docker-mpm-event && \
  a2disconf other-vhosts-access-log
echo "======   End: ENABLE APACHE CONFIGS ======"
exit 0
