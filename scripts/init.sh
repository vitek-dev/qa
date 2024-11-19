#!/bin/bash

if [ -z "$(ls -A /app)" ]; then
    echo "Source directory is empty, have you mounted volume to /app?"
    exit 1;
fi

## PHPSTAN

CONFIG_PHPSTAN="/app/phpstan.neon"
if [ -f "$CONFIG_PHPSTAN" ]; then
    echo "$CONFIG_PHPSTAN already exists."
else
    echo "$CONFIG_PHPSTAN does not exist. Creating it..."

    cat <<EOL > $CONFIG_PHPSTAN
parameters:
    level: 5 # Adjust the level (0-9 or max)
    paths:
        - src
    # excludes_analyse:

    checkMissingIterableValueType: true
EOL

    echo "$CONFIG_PHPSTAN created with a basic structure."
fi

## PHP CS

CONFIG_PHPCS="/app/phpcs.xml"
if [ -f "$CONFIG_PHPCS" ]; then
    echo "$CONFIG_PHPCS already exists."
else
    echo "$CONFIG_PHPCS does not exist. Creating it..."

    cat <<EOL > $CONFIG_PHPCS
<?xml version="1.0"?>
<ruleset name="Coding standard">
    <rule ref="VitekDevCodingStandard"/>

    <file>src</file>

    <exclude-pattern>*/vendor/*</exclude-pattern>

    <extensions>
        <extension name="php"/>
    </extensions>

    <arg name="severity" value="2"/>
    <arg name="tab-width" value="4"/>
</ruleset>
EOL

    echo "$CONFIG_PHPCS created with a basic structure."
fi
