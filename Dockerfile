FROM php:%%PHP_VERSION%%-alpine

# system dependencies
RUN apk add --no-cache git unzip libzip \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS libzip-dev \
    && docker-php-ext-install zip \
    && apk del .build-deps

# copy files
#   /config/<tool>/...           -> default phpstan.neon / phpcs.xml / deptrac.yaml that `init` copies into /app
#   /config/phpcs/standards/...  -> VitekDevCodingStandard ruleset (registered via installed_paths below)
COPY scripts /scripts
COPY config /config

RUN ln -s /scripts/init.sh /usr/local/bin/init \
    && chmod +x /scripts/* \
    && mkdir /app

# composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
RUN composer global config --no-plugins allow-plugins.dealerdirect/phpcodesniffer-composer-installer true \
    && composer global config minimum-stability dev

# Install QA tools globally with Composer
RUN composer global require -a -o --no-interaction --prefer-stable --dev --ignore-platform-reqs \
        phpstan/phpstan \
        squizlabs/php_codesniffer \
        qossmic/deptrac \
        slevomat/coding-standard

# phpcs & phpcbf
RUN ln -s $HOME/.composer/vendor/bin/phpcs /usr/local/bin/phpcs \
    && ln -s $HOME/.composer/vendor/bin/phpcs /usr/local/bin/cs \
    && ln -s $HOME/.composer/vendor/bin/phpcbf /usr/local/bin/phpcbf \
    && ln -s $HOME/.composer/vendor/bin/phpcbf /usr/local/bin/cbf \
    && phpcs --config-set installed_paths $HOME/.composer/vendor/slevomat/coding-standard,/config/phpcs/standards

# phpstan
RUN ln -s $HOME/.composer/vendor/bin/phpstan /usr/local/bin/phpstan \
    && ln -s $HOME/.composer/vendor/bin/phpstan /usr/local/bin/stan

# deptrac
RUN ln -s $HOME/.composer/vendor/bin/deptrac /usr/local/bin/deptrac


# entrypoint
WORKDIR /app
CMD ["sh"]
