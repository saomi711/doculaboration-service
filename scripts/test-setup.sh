#!/bin/bash

# Test script to verify the complete setup
echo "🧪 Testing Doculaboration Setup"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_result=${3:-0}
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        if [ $? -eq $expected_result ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test HTTP endpoint
test_http() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    echo -n "Testing $name... "
    
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [ "$response" = "$expected_code" ]; then
            echo -e "${GREEN}✓ PASS${NC} ($response)"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} ($response)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "${YELLOW}? SKIP${NC} (curl not available)"
        return 0
    fi
}

echo -e "${BLUE}Phase 1: Prerequisites${NC}"
echo "------------------------"

run_test "Docker installed" "docker --version"
run_test "Docker Compose installed" "docker-compose --version"
run_test "Make installed" "make --version"

echo ""
echo -e "${BLUE}Phase 2: File Structure${NC}"
echo "------------------------"

run_test "Docker Compose file exists" "test -f docker-compose.yml"
run_test "Nginx config exists" "test -f nginx/nginx.conf"
run_test "Frontend Dockerfile exists" "test -f frontend/Dockerfile"
run_test "Backend Dockerfile exists" "test -f backend/Dockerfile"
run_test "Makefile exists" "test -f Makefile"

echo ""
echo -e "${BLUE}Phase 3: Port Configuration${NC}"
echo "-----------------------------"

# Check if ports are available
run_test "Port 80 available" "! netstat -tuln 2>/dev/null | grep -q ':80 '"
run_test "Port 4200 available" "! netstat -tuln 2>/dev/null | grep -q ':4200 '"
run_test "Port 9001 available" "! netstat -tuln 2>/dev/null | grep -q ':9001 '"

echo ""
echo -e "${BLUE}Phase 4: Configuration Files${NC}"
echo "------------------------------"

# Check nginx configuration
if grep -q "server frontend:4200" nginx/nginx.conf; then
    echo -e "Nginx upstream config... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "Nginx upstream config... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Check frontend nginx config
if grep -q "listen 4200" frontend/nginx.conf; then
    echo -e "Frontend nginx config... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "Frontend nginx config... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

# Check docker-compose dev config
if grep -q "9001:7000" docker-compose.dev.yml; then
    echo -e "Docker compose dev config... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "Docker compose dev config... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo -e "${BLUE}Phase 5: Build Test${NC}"
echo "--------------------"

echo "Building images (this may take a while)..."
if docker-compose build --quiet >/dev/null 2>&1; then
    echo -e "Docker images build... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "Docker images build... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo -e "${BLUE}Phase 6: Service Startup Test${NC}"
echo "-------------------------------"

echo "Starting services in production mode..."
if docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d >/dev/null 2>&1; then
    echo -e "Services startup... ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
    
    # Wait for services to be ready
    echo "Waiting for services to be ready..."
    sleep 10
    
    # Test endpoints - detect correct port
    if netstat -tuln 2>/dev/null | grep -q ':80 '; then
        BASE_URL="http://localhost"
    else
        BASE_URL="http://localhost:9000"
    fi
    
    test_http "$BASE_URL/health" "Nginx health endpoint"
    test_http "$BASE_URL/" "Frontend through Nginx"
    test_http "http://localhost:15672" "RabbitMQ Management"
    
    # Cleanup
    echo "Cleaning up test services..."
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml down >/dev/null 2>&1
else
    echo -e "Services startup... ${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo "================================"
echo -e "${BLUE}Test Results Summary${NC}"
echo "================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed! Your setup is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run 'make dev' for development mode"
    echo "2. Run 'make prod' for production mode"
    echo "3. Run 'make health' to check service health"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please check the configuration.${NC}"
    exit 1
fi