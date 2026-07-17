#!/bin/bash

#
# Pterodactyl Panel Start Script
# This script initializes and starts all services
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Configuration
# =============================================================================

# Environment variables
APP_ENV="${APP_ENV:-production}"
APP_DEBUG="${APP_DEBUG:-false}"
APP_URL="${APP_URL:-https://pterodactyl.yourdomain.com}"
DB_HOST="${DB_HOST:-database}"
DB_PORT="${DB_PORT:-3306}"
DB_DATABASE="${DB_DATABASE:-pterodactyl_panel_production}"
DB_USERNAME="${DB_USERNAME:-pterodactyl_user}"
DB_PASSWORD="${DB_PASSWORD:-pterodactyl_secure_pass_2024}"
REDIS_HOST="${REDIS_HOST:-cache}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-redis_secure_password_2024}"

# Paths
APP_PATH="/app"
STORAGE_PATH="/app/storage"
LOG_PATH="/app/storage/logs"
CONFIG_PATH="/app/config"
PUBLIC_PATH="/app/public"
VENDOR_PATH="/app/vendor"
BOOTSTRAP_PATH="/app/bootstrap"
ROUTES_PATH="/app/routes"
DATABASE_PATH="/app/database"
RESOURCES_PATH="/app/resources"

# =============================================================================
# Functions
# =============================================================================

# ===== ERROR 1: Syntax error - missing closing bracket in function =====
print_header() {
    echo ""
    echo "========================================="
    echo "  Pterodactyl Panel - Starting Up"
    echo "  Environment: ${APP_ENV}"
    echo "  Debug Mode: ${APP_DEBUG}"
    echo "========================================="
    echo ""
# <-- Missing closing bracket here!

# ===== ERROR 2: Command not found - using undefined variable =====
check_requirements() {
    echo -e "${BLUE}[INFO]${NC} Checking system requirements..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Docker is not running or not installed!"
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}[WARN]${NC} docker-compose not found, trying docker compose..."
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
    
    # Check if .env file exists
    if [ ! -f "${APP_PATH}/.env" ]; then
        echo -e "${YELLOW}[WARN]${NC} .env file not found, creating from example..."
        cp "${APP_PATH}/.env.example" "${APP_PATH}/.env" || {
            echo -e "${RED}[ERROR]${NC} Failed to create .env file!"
            exit 1
        }
    fi
    
    # Check if storage directory is writable
    if [ ! -w "${STORAGE_PATH}" ]; then
        echo -e "${YELLOW}[WARN]${NC} Storage directory not writable, fixing permissions..."
        chmod -R 775 "${STORAGE_PATH}" || {
            echo -e "${RED}[ERROR]${NC} Failed to set permissions on storage directory!"
            exit 1
        }
    fi
    
    # Check if vendor directory exists
    if [ ! -d "${VENDOR_PATH}" ]; then
        echo -e "${YELLOW}[WARN]${NC} Vendor directory not found, running composer install..."
        composer install --no-interaction --optimize-autoloader || {
            echo -e "${RED}[ERROR]${NC} Composer install failed!"
            exit 1
        }
    fi
    
    # Check database connection
    echo -e "${BLUE}[INFO]${NC} Checking database connection..."
    if ! php artisan db:monitor > /dev/null 2>&1; then
        echo -e "${YELLOW}[WARN]${NC} Database connection failed, waiting for database to be ready..."
        wait_for_database
    fi
    
    # Check Redis connection
    echo -e "${BLUE}[INFO]${NC} Checking Redis connection..."
    if ! php artisan cache:ping > /dev/null 2>&1; then
        echo -e "${YELLOW}[WARN]${NC} Redis connection failed, waiting for Redis to be ready..."
        wait_for_redis
    fi
    
    echo -e "${GREEN}[OK]${NC} All requirements satisfied!"
}

# ===== ERROR 3: Infinite loop - missing sleep or break condition =====
wait_for_database() {
    echo -e "${BLUE}[INFO]${NC} Waiting for database to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        if mysqladmin ping -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" --silent 2>/dev/null; then
            echo -e "${GREEN}[OK]${NC} Database is ready!"
            return 0
        fi
        echo -e "${YELLOW}[WARN]${NC} Database not ready yet (attempt ${attempt}/${max_attempts})..."
        # MISSING: sleep 2 here! <-- This will cause infinite loop without sleep
    done
    
    echo -e "${RED}[ERROR]${NC} Database failed to become ready!"
    return 1
}

# ===== ERROR 4: Variable name conflict with environment variable =====
wait_for_redis() {
    echo -e "${BLUE}[INFO]${NC} Waiting for Redis to be ready..."
    local max_attempts=20
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q "PONG"; then
            echo -e "${GREEN}[OK]${NC} Redis is ready!"
            return 0
        fi
        echo -e "${YELLOW}[WARN]${NC} Redis not ready yet (attempt ${attempt}/${max_attempts})..."
        sleep 2
    done
    
    echo -e "${RED}[ERROR]${NC} Redis failed to become ready!"
    return 1
}

# ===== ERROR 5: Typo in command - php artisan with wrong command =====
run_migrations() {
    echo -e "${BLUE}[INFO]${NC} Running database migrations..."
    php artisan migrat --force || {
        echo -e "${RED}[ERROR]${NC} Migration failed!"
        exit 1
    }
    
    echo -e "${BLUE}[INFO]${NC} Seeding database..."
    php artisan db:seed --force || {
        echo -e "${YELLOW}[WARN]${NC} Seeding failed, continuing anyway..."
    }
}

# ===== ERROR 6: Using unquoted variable that contains spaces =====
cache_clear() {
    echo -e "${BLUE}[INFO]${NC} Clearing cache..."
    php artisan config:clear
    php artisan cache:clear
    php artisan view:clear
    php artisan route:clear
    
    echo -e "${BLUE}[INFO]${NC} Optimizing application..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    
    echo -e "${BLUE}[INFO]${NC} Building frontend assets..."
    npm run production || {
        echo -e "${YELLOW}[WARN]${NC} Asset build failed!"
    }
}

# ===== ERROR 7: Missing quotes in variable assignment =====
start_services() {
    echo -e "${BLUE}[INFO]${NC} Starting services..."
    
    # Start queue worker
    echo -e "${BLUE}[INFO]${NC} Starting queue worker..."
    php artisan queue:work --daemon --timeout=300 --sleep=3 --tries=3 &
    QUEUE_PID=$!
    
    # Start schedule worker
    echo -e "${BLUE}[INFO]${NC} Starting schedule worker..."
    php artisan schedule:work --no-interaction &
    SCHEDULE_PID=$!
    
    # Start horizon if in production
    if [ "${APP_ENV}" = "production" ]; then
        echo -e "${BLUE}[INFO]${NC} Starting Horizon..."
        php artisan horizon &
        HORIZON_PID=$!
    fi
    
    echo -e "${GREEN}[OK]${NC} All services started!"
}

# ===== ERROR 8: Unclosed string in echo =====
print_footer() {
    echo ""
    echo "========================================="
    echo "  Pterodactyl Panel is ready!
    echo "  URL: ${APP_URL}
    echo "  PID: $$"
    echo "========================================="
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Pterodactyl Panel - Startup Script                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

print_header
check_requirements
run_migrations
cache_clear
start_services
print_footer

echo -e "${GREEN}[OK]${NC} Startup complete! Waiting for processes..."
wait $QUEUE_PID $SCHEDULE_PID ${HORIZON_PID:-}

# ===== ERROR 9: Missing trap for signal handling =====
# No trap defined, so Ctrl+C won't clean up properly

# =============================================================================
# End of script
# =============================================================================
