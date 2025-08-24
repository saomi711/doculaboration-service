#!/bin/bash

# Production monitoring script
echo "📊 Doculaboration Production Monitor"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to get container stats
get_container_stats() {
    local container=$1
    local name=$2
    
    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        local cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" $container 2>/dev/null)
        local mem=$(docker stats --no-stream --format "{{.MemUsage}}" $container 2>/dev/null)
        local status=$(docker inspect --format="{{.State.Status}}" $container 2>/dev/null)
        
        echo -e "$name: ${GREEN}$status${NC} | CPU: $cpu | Memory: $mem"
    else
        echo -e "$name: ${RED}not running${NC}"
    fi
}

# Function to check disk usage
check_disk_usage() {
    echo -e "${BLUE}Disk Usage:${NC}"
    df -h | grep -E "(Filesystem|/dev/)" | head -2
    
    # Check out directory size
    if [ -d "out" ]; then
        local out_size=$(du -sh out 2>/dev/null | cut -f1)
        echo "Generated files (out/): $out_size"
    fi
}

# Function to check service endpoints
check_endpoints() {
    echo -e "${BLUE}Service Endpoints:${NC}"
    
    # Detect the correct base URL based on what's running
    if netstat -tuln 2>/dev/null | grep -q ':80 '; then
        BASE_URL="http://localhost"
    else
        BASE_URL="http://localhost:9000"
    fi
    
    endpoints=(
        "$BASE_URL/health:Nginx Health"
        "$BASE_URL/api/health:API Health"
        "$BASE_URL/:Frontend"
        "http://localhost:15672:RabbitMQ"
    )
    
    for endpoint in "${endpoints[@]}"; do
        IFS=':' read -r url name <<< "$endpoint"
        
        if command -v curl >/dev/null 2>&1; then
            response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
            if [ "$response" = "200" ]; then
                echo -e "$name: ${GREEN}✓ OK${NC} ($response)"
            else
                echo -e "$name: ${RED}✗ FAIL${NC} ($response)"
            fi
        else
            echo -e "$name: ${YELLOW}? SKIP${NC} (curl not available)"
        fi
    done
}

# Function to check queue status
check_queues() {
    echo -e "${BLUE}Queue Status:${NC}"
    
    if command -v curl >/dev/null 2>&1; then
        # Check RabbitMQ queues via management API
        local queue_info=$(curl -s -u guest:guest "http://localhost:15672/api/queues" 2>/dev/null)
        if [ $? -eq 0 ] && [ "$queue_info" != "" ]; then
            echo "RabbitMQ queues accessible via management API"
        else
            echo "Unable to fetch queue information"
        fi
    fi
    
    # Check Redis
    if command -v redis-cli >/dev/null 2>&1; then
        local redis_info=$(redis-cli -h localhost -p 6379 info keyspace 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "Redis: ${GREEN}✓ Connected${NC}"
            if [ "$redis_info" != "" ]; then
                echo "Redis keyspace: $redis_info"
            else
                echo "Redis keyspace: empty"
            fi
        else
            echo -e "Redis: ${RED}✗ Connection failed${NC}"
        fi
    fi
}

# Function to show recent logs
show_recent_logs() {
    echo -e "${BLUE}Recent Logs (last 10 lines):${NC}"
    echo "--------------------------------"
    
    services=("nginx" "api" "worker")
    
    for service in "${services[@]}"; do
        echo -e "${YELLOW}$service:${NC}"
        docker-compose logs --tail=3 $service 2>/dev/null | tail -3
        echo ""
    done
}

# Main monitoring loop
while true; do
    clear
    echo "📊 Doculaboration Production Monitor"
    echo "===================================="
    echo "$(date)"
    echo ""
    
    echo -e "${BLUE}Container Status:${NC}"
    get_container_stats "doculaboration_nginx" "Nginx"
    get_container_stats "doculaboration_frontend" "Frontend"
    get_container_stats "doculaboration_backend" "Backend"
    get_container_stats "redis" "Redis"
    get_container_stats "rabbitmq" "RabbitMQ"
    echo ""
    
    check_disk_usage
    echo ""
    
    check_endpoints
    echo ""
    
    check_queues
    echo ""
    
    show_recent_logs
    
    echo "Press Ctrl+C to exit, or wait 30 seconds for refresh..."
    sleep 30
done