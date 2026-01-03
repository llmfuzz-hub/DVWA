FROM docker.io/library/php:8-apache

LABEL org.opencontainers.image.source=https://github.com/digininja/DVWA
LABEL org.opencontainers.image.description="DVWA pre-built image."
LABEL org.opencontainers.image.licenses="gpl-3.0"

WORKDIR /var/www/html

# https://www.php.net/manual/en/image.installation.php
RUN apt-get update \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get install -y zlib1g-dev libpng-dev libjpeg-dev libfreetype6-dev iputils-ping git libzip-dev unzip \
 && apt-get clean -y && rm -rf /var/lib/apt/lists/* \
 && docker-php-ext-configure gd --with-jpeg --with-freetype \
 && a2enmod rewrite \
 # Use pdo_sqlite instead of pdo_mysql if you want to use sqlite
 && docker-php-ext-install gd mysqli pdo pdo_mysql zip \
 && pecl install xdebug \
 && docker-php-ext-enable xdebug \
 && mkdir -p /tmp/xdebug \
 && chown www-data:www-data /tmp/xdebug \
 && printf '%s\n' \
        '; zend_extension=xdebug.so (already loaded by docker-php-ext-enable)' \
        'xdebug.mode=trace' \
        'xdebug.start_with_request=trigger' \
        'xdebug.trigger_value=1' \
        'xdebug.output_dir=/tmp/xdebug' \
        'xdebug.collect_return=1' \
        'xdebug.collect_params=4' \
        'xdebug.trace_format=0' \
        'xdebug.trace_options=0' \
        'xdebug.trace_output_name=trace.%t.%u' \
        'xdebug.log_level=0' \
    > /usr/local/etc/php/conf.d/99-xdebug.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY --chown=www-data:www-data . .
COPY --chown=www-data:www-data config/config.inc.php.dist config/config.inc.php

# This is configuring the stuff for the API
RUN cd /var/www/html/vulnerabilities/api \
 && composer install \
