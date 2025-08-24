#!/bin/bash

# Quick status check script
echo "🚀 Doculaboration Quick Status"
echo "=============================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect correct base URL
if netstat -tuln 2>/dev/null | grep -q ':80 '; then
    BASE_URL="http://localhost"
    MODE="Production (Port 80)"
else
    BASE_URL="http://localhost:9000"
    MODE="Production (Port 9000)"
fi

echo -e "${BLUE}Mode:${NC} $MODE"
echo ""

# Quick container check
echo -e "${BLUE}Containers:${NC}"
docker compose ps --format "table {{.Service}}\t{{.Status}}" | grep -v "SERVICE"

echo ""

# Quick endpoint check
echo -e "${BLUE}Endpoints:${NC}"
endpoints=(
    "$BASE_URL/health:Nginx"
    "$BASE_URL/api/health:API"
    "$BASE_URL/:Frontend"
    "http://localhost:15672:RabbitMQ"
)

for endpoint in "${endpoints[@]}"; do
    # Split on the last colon to handle URLs with colons
    url="${endpoint%:*}"
    name="${endpoint##*:}"
    
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [ "$response" = "200" ]; then
            echo -e "$name: ${GREEN}✓ $response${NC}"
        else
            echo -e "$name: ${RED}✗ $response${NC}"
        fi
    else
        echo -e "$name: ${YELLOW}? No curl${NC}"
    fi
done

echo ""
echo -e "${BLUE}Access:${NC}"
echo "🌐 Application: $BASE_URL"
echo "📊 RabbitMQ: http://localhost:15672 (guest/guest)"

echo ""
echo "For detailed monitoring: make monitor"
echo "For full health check: make health"