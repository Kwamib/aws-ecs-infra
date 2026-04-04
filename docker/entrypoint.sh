#!/bin/bash
set -e

echo "Starting WordPress container with custom configuration..."

# Validate required environment variables
echo "Checking required environment variables..."
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ]; then
    echo "ERROR: Missing required database environment variables"
    echo "DB_NAME: ${DB_NAME:-MISSING}"
    echo "DB_USER: ${DB_USER:-MISSING}"
    echo "DB_PASSWORD: ${DB_PASSWORD:+SET}"
    echo "DB_HOST: ${DB_HOST:-MISSING}"
    exit 1
fi

echo "Generating wp-config.php from environment variables..."

cat > /var/www/html/wp-config.php << EOF
<?php
// Force HTTPS behind load balancer
\$_SERVER['HTTPS'] = 'on';
\$_SERVER['SERVER_PORT'] = 443;

// WordPress URLs (set via ECS task environment variables)
define('WP_HOME', '${WP_HOME}');
define('WP_SITEURL', '${WP_SITEURL}');

// Database settings (injected from SSM Parameter Store via ECS secrets)
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${DB_HOST}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// Security keys — generate from https://api.wordpress.org/secret-key/1.1/salt/
define('AUTH_KEY',         '${AUTH_KEY:-REPLACE_WITH_UNIQUE_PHRASE}');
define('SECURE_AUTH_KEY',  '${SECURE_AUTH_KEY:-REPLACE_WITH_UNIQUE_PHRASE}');
define('LOGGED_IN_KEY',    '${LOGGED_IN_KEY:-REPLACE_WITH_UNIQUE_PHRASE}');
define('NONCE_KEY',        '${NONCE_KEY:-REPLACE_WITH_UNIQUE_PHRASE}');
define('AUTH_SALT',        '${AUTH_SALT:-REPLACE_WITH_UNIQUE_PHRASE}');
define('SECURE_AUTH_SALT', '${SECURE_AUTH_SALT:-REPLACE_WITH_UNIQUE_PHRASE}');
define('LOGGED_IN_SALT',   '${LOGGED_IN_SALT:-REPLACE_WITH_UNIQUE_PHRASE}');
define('NONCE_SALT',       '${NONCE_SALT:-REPLACE_WITH_UNIQUE_PHRASE}');

\$table_prefix = 'wp_';
define('WP_DEBUG', false);

if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF

echo "wp-config.php generated successfully"

chown www-data:www-data /var/www/html/wp-config.php
chmod 644 /var/www/html/wp-config.php

echo "WordPress configuration complete. Starting Apache..."
exec "$@"
