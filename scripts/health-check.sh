#!/bin/bash

# Health check script for all services
echo "🏥 Doculaboration Health Check"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check HTTP endpoint
check_http() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    echo -n "Checking $name... "
    
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [ "$response" = "$expected_code" ]; then
            echo -e "${GREEN}✓ OK${NC} ($response)"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} ($response)"
            return 1
        fi
    else
        echo -e "${YELLOW}? SKIP${NC} (curl not available)"
        return 0
    fi
}

# Function to check Docker container
check_container() {
    local container=$1
    local name=$2
    
    echo -n "Checking $name container... "
    
    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        echo -e "${GREEN}✓ RUNNING${NC}"
        return 0
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        return 1
    fi
}

# Check Docker containers
echo "📦 Container Status:"
check_container "doculaboration_nginx" "Nginx"
check_container "doculaboration_frontend" "Frontend"
check_container "doculaboration_backend" "Backend API"
check_container "redis" "Redis"
check_container "rabbitmq" "RabbitMQ"

echo ""

# Check HTTP endpoints
echo "🌐 HTTP Endpoints:"
# Check if we're in production mode (port 80) or development mode (port 9000)
if netstat -tuln 2>/dev/null | grep -q ':80 '; then
    BASE_URL="http://localhost"
else
    BASE_URL="http://localhost:9000"
fi

check_http "$BASE_URL/health" "Nginx Health"
check_http "$BASE_URL/api/health" "API Health"
check_http "$BASE_URL/" "Frontend" 200
check_http "http://localhost:15672" "RabbitMQ Management"

echo ""

# Check Redis
echo -n "Checking Redis connection... "
if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAIL${NC}"
    fi
else
    echo -e "${YELLOW}? SKIP${NC} (redis-cli not available)"
fi

echo ""
echo "🏁 Health check complete!"