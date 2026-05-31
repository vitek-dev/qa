#!/bin/sh

if [ -z "$(ls -A /app)" ]; then
    echo "Source directory is empty, have you mounted volume to /app?"
    exit 1;
fi

# install_config <source-path> <destination-filename>
# Copies a default config from the image into the mounted project,
# but never overwrites a file the consumer already has.
install_config() {
    source="$1"
    destination="/app/$2"

    if [ -f "$destination" ]; then
        echo "$destination already exists, skipping."
    else
        cp "$source" "$destination"
        echo "$destination created."
    fi
}

install_config /config/phpstan/phpstan.neon          phpstan.neon
install_config /config/phpstan/phpstan-baseline.neon phpstan-baseline.neon
install_config /config/phpcs/phpcs.xml               phpcs.xml
install_config /config/deptrac/deptrac.yaml          deptrac.yaml
