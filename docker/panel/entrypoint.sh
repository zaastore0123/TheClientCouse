#!/bin/bash

#
# Pterodactyl Panel Docker Entrypoint
# This script runs inside the container to initialize the environment
#

set -e

# =============================================================================
# Configuration
# =============================================================================

# User and group IDs for file permissions
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Application paths
APP_PATH="/app"
STORAGE_PATH="${APP_PATH}/storage"
BOOTSTRAP_CACHE_PATH="${APP_PATH}/bootstrap/cache"
PUBLIC_PATH="${APP_PATH}/public"
VENDOR_PATH="${APP_PATH}/vendor"
CONFIG_PATH="${APP_PATH}/config"
DATABASE_PATH="${APP_PATH}/database"
RESOURCES_PATH="${APP_PATH}/resources"
ROUTES_PATH="${APP_PATH}/routes"
LANG_PATH="${APP_PATH}/lang"
TESTS_PATH="${APP_PATH}/tests"

# =============================================================================
# Functions
# =============================================================================

# ===== ERROR 1: Syntax error - wrong condition syntax =====
set_permissions() {
    echo "[ENTRYPOINT] Setting file permissions..."
    
    # Create necessary directories if they don't exist
    mkdir -p ${STORAGE_PATH}/app
    mkdir -p ${STORAGE_PATH}/framework/cache
    mkdir -p ${STORAGE_PATH}/framework/sessions
    mkdir -p ${STORAGE_PATH}/framework/views
    mkdir -p ${STORAGE_PATH}/logs
    mkdir -p ${BOOTSTRAP_CACHE_PATH}
    mkdir -p ${PUBLIC_PATH}/uploads
    
    # Set ownership
    if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
        echo "[ENTRYPOINT] Setting ownership to ${PUID}:${PGID}"
        if [ ${PUID} -ne 0 ] && [ ${PGID} -ne 0 ]; then
            # ERROR: Wrong syntax for if condition - missing spaces
            if[ ${PUID} -eq 1000 ] && [ ${PGID} -eq 1000 ]; then
                chown -R ${PUID}:${PGID} ${STORAGE_PATH} || true
                chown -R ${PUID}:${PGID} ${BOOTSTRAP_CACHE_PATH} || true
                chown -R ${PUID}:${PGID} ${PUBLIC_PATH}/uploads || true
            fi
        fi
    fi
    
    # Set permissions
    chmod -R 775 ${STORAGE_PATH}
    chmod -R 775 ${BOOTSTRAP_CACHE_PATH}
    chmod -R 775 ${PUBLIC_PATH}/uploads
    
    echo "[ENTRYPOINT] Permissions set successfully!"
}

# ===== ERROR 2: Command not found - composer with wrong option =====
install_dependencies() {
    echo "[ENTRYPOINT] Installing dependencies..."
    
    # Check if composer.json exists
    if [ -f "${APP_PATH}/composer.json" ]; then
        echo "[ENTRYPOINT] Running composer install..."
        composer install --no-interaction --optimize-autoloader --no-dev || {
            echo "[ERROR] Composer install failed!"
            return 1
        }
        
        # ERROR: Wrong option --dump-autoload should be dump-autoload
        composer dump-autoload --optimize --classmap-authoritative
        
        # Check if npm is available
        if command -v npm &> /dev/null; then
            if [ -f "${APP_PATH}/package.json" ]; then
                echo "[ENTRYPOINT] Installing npm dependencies..."
                npm install --production --no-audit --no-fund || {
                    echo "[WARN] npm install failed!"
                }
                
                echo "[ENTRYPOINT] Building assets..."
                npm run production || {
                    echo "[WARN] Asset build failed!"
                }
            fi
        fi
    else
        echo "[WARN] composer.json not found!"
    fi
}

# ===== ERROR 3: Unclosed string in variable =====
generate_environment() {
    echo "[ENTRYPOINT] Generating environment configuration..."
    
    # Check if .env exists
    if [ ! -f "${APP_PATH}/.env" ]; then
        echo "[ENTRYPOINT] Creating .env from example..."
        cp "${APP_PATH}/.env.example" "${APP_PATH}/.env"
    fi
    
    # Update .env with environment variables
    echo "[ENTRYPOINT] Updating .env with environment variables..."
    
    # ERROR: Unclosed string here - missing closing quote
    sed -i "s/APP_URL=.*/APP_URL=${APP_URL:-https://pterodactyl.yourdomain.com}/" "${APP_PATH}/.env"
    sed -i "s/APP_ENV=.*/APP_ENV=${APP_ENV:-production}/" "${APP_PATH}/.env"
    sed -i "s/APP_DEBUG=.*/APP_DEBUG=${APP_DEBUG:-false}/" "${APP_PATH}/.env"
    sed -i "s/DB_HOST=.*/DB_HOST=${DB_HOST:-database}/" "${APP_PATH}/.env"
    sed -i "s/DB_PORT=.*/DB_PORT=${DB_PORT:-3306}/" "${APP_PATH}/.env"
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE:-pterodactyl_panel_production}/" "${APP_PATH}/.env"
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME:-pterodactyl_user}/" "${APP_PATH}/.env"
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD:-pterodactyl_secure_pass_2024}/" "${APP_PATH}/.env"
    sed -i "s/REDIS_HOST=.*/REDIS_HOST=${REDIS_HOST:-cache}/" "${APP_PATH}/.env"
    sed -i "s/REDIS_PORT=.*/REDIS_PORT=${REDIS_PORT:-6379}/" "${APP_PATH}/.env"
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PASSWORD:-redis_secure_password_2024}/" "${APP_PATH}/.env"
}

# ===== ERROR 4: Wrong variable name causing expansion error =====
run_artisan_commands() {
    echo "[ENTRYPOINT] Running artisan commands..."
    
    # Generate application key if not set
    if ! grep -q "APP_KEY=" "${APP_PATH}/.env" || [ -z "$(grep APP_KEY= "${APP_PATH}/.env" | cut -d= -f2)" ]; then
        echo "[ENTRYPOINT] Generating application key..."
        php artisan key:generate --force || {
            echo "[ERROR] Key generation failed!"
            return 1
        }
    fi
    
    # Run migrations
    echo "[ENTRYPOINT] Running migrations..."
    php artisan migrate --force || {
        echo "[WARN] Migration failed!"
    }
    
    # Clear cache
    echo "[ENTRYPOINT] Clearing cache..."
    php artisan config:clear
    php artisan cache:clear
    php artisan view:clear
    php artisan route:clear
    
    # Cache configuration
    if [ "${APP_ENV:-production}" = "production" ]; then
        echo "[ENTRYPOINT] Caching configuration..."
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache
        
        # ERROR: Wrong variable name - should be HORIZON_ENABLED
        if [ "${HORIZON_ENABLED:-false}" = "true" ]; then
            echo "[ENTRYPOINT] Caching Horizon configuration..."
            php artisan horizon:publish --force
        fi
    fi
    
    # Set storage link
    echo "[ENTRYPOINT] Creating storage link..."
    php artisan storage:link --force || {
        echo "[WARN] Storage link creation failed!"
    }
}

# ===== ERROR 5: Infinite recursion - function calling itself =====
health_check() {
    echo "[ENTRYPOINT] Running health check..."
    
    # Check if application is running
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "[ENTRYPOINT] Health check passed!"
        return 0
    else
        echo "[ERROR] Health check failed!"
        # ERROR: This will cause infinite recursion
        health_check
        return 1
    fi
}

# ===== ERROR 6: Wrong array syntax in bash =====
start_supervisor() {
    echo "[ENTRYPOINT] Starting supervisor..."
    
    # Start PHP-FPM
    echo "[ENTRYPOINT] Starting PHP-FPM..."
    php-fpm -D || {
        echo "[ERROR] PHP-FPM failed to start!"
        return 1
    }
    
    # Start Nginx
    echo "[ENTRYPOINT] Starting Nginx..."
    nginx -g "daemon off;" &
    NGINX_PID=$!
    
    # ERROR: Wrong array syntax - should be separated by space
    SUPERVISOR_COMMANDS=(
        "php artisan queue:work --daemon --timeout=300 --sleep=3 --tries=3"
        "php artisan schedule:work --no-interaction"
        "php artisan horizon"
    )
    
    # Start supervisor processes
    for cmd in ${SUPERVISOR_COMMANDS}; do
        echo "[ENTRYPOINT] Starting: ${cmd}"
        eval "${cmd}" &
    done
}

# ===== ERROR 7: Missing closing quote in echo =====
trap_signals() {
    echo "[ENTRYPOINT] Setting up signal handlers..."
    
    # Trap SIGTERM and SIGINT
    trap 'echo "[ENTRYPOINT] Received SIGTERM, shutting down..."; kill -TERM $NGINX_PID; exit 0' TERM
    trap 'echo "[ENTRYPOINT] Received SIGINT, shutting down..."; kill -INT $NGINX_PID; exit 0' INT
    
    # Trap SIGQUIT
    trap 'echo "[ENTRYPOINT] Received SIGQUIT, shutting down..."; kill -QUIT $NGINX_PID; exit 0' QUIT
    
    # Trap SIGHUP
    trap 'echo "[ENTRYPOINT] Received SIGHUP, reloading..."; kill -HUP $NGINX_PID' HUP
}

# ===== ERROR 8: Using undefined variable in condition =====
main() {
    echo "[ENTRYPOINT] ========================================"
    echo "[ENTRYPOINT] Pterodactyl Panel Entrypoint"
    echo "[ENTRYPOINT] ========================================"
    
    # Set permissions
    set_permissions
    
    # Install dependencies
    install_dependencies
    
    # Generate environment
    generate_environment
    
    # Run artisan commands
    run_artisan_commands
    
    # Start supervisor
    start_supervisor
    
    # Set up signal handlers
    trap_signals
    
    # Error: Using undefined variable ${UNDEFINED_VAR}
    if [ -n "${UNDEFINED_VAR}" ]; then
        echo "[ENTRYPOINT] Undefined variable is set!"
    fi
    
    # Wait for all processes
    echo "[ENTRYPOINT] All services started successfully!"
    
    # Health check
    health_check
    
    # Error: Missing closing quote in echo - unclosed string
    echo "[ENTRYPOINT] Container is ready! Waiting for signals...
}

# =============================================================================
# Execute main
# =============================================================================

main

# ===== ERROR 9: Missing exit code =====
# No exit statement, so exit code may not be 0

# =============================================================================
# End of script
# =============================================================================
