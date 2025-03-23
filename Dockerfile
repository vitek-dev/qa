FROM php:8.4-bookworm

# system updates & dependencies
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    wget

RUN docker-php-ext-install zip

# copy files
COPY scripts /scripts

RUN ln -s /scripts/init.sh /usr/local/bin/init \
    && chmod +x /scripts/* \
    && mkdir /app

# composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
RUN composer global config --no-plugins allow-plugins.dealerdirect/phpcodesniffer-composer-installer true \
    && composer global config minimum-stability dev

# Install QA tools globally with Composer
RUN composer global config repositories.vd-coding-standard git https://github.com/vitek-dev/coding-standard.git \
    && composer global require -a -o --no-interaction --prefer-stable --dev \
        phpstan/phpstan \
        squizlabs/php_codesniffer \
        qossmic/deptrac \
        vitek-dev/coding-standard \
        slevomat/coding-standard

# phpcs & phpcbf
RUN ln -s $HOME/.composer/vendor/bin/phpcs /usr/local/bin/phpcs \
    && ln -s $HOME/.composer/vendor/bin/phpcs /usr/local/bin/cs \
    && ln -s $HOME/.composer/vendor/bin/phpcbf /usr/local/bin/phpcbf \
    && ln -s $HOME/.composer/vendor/bin/phpcbf /usr/local/bin/cbf \
    && phpcs --config-set installed_paths $HOME/.composer/vendor/slevomat/coding-standard,$HOME/.composer/vendor/vitek-dev/coding-standard

# phpstan
RUN ln -s $HOME/.composer/vendor/bin/phpstan /usr/local/bin/phpstan \
    && ln -s $HOME/.composer/vendor/bin/phpstan /usr/local/bin/stan

# deptrac
RUN ln -s $HOME/.composer/vendor/bin/deptrac /usr/local/bin/deptrac


# entrypoint
WORKDIR /app
CMD ["bash"]