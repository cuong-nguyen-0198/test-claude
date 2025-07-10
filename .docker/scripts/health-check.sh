#!/bin/bash

# Health check script for Laravel application

# Check if nginx is running
if ! pgrep nginx > /dev/null; then
    echo "Nginx is not running"
    exit 1
fi

# Check if php-fpm is running
if ! pgrep php-fpm > /dev/null; then
    echo "PHP-FPM is not running"
    exit 1
fi

# Check if the application responds
if ! curl -f http://localhost/health > /dev/null 2>&1; then
    echo "Application health check failed"
    exit 1
fi

echo "All health checks passed"
exit 0