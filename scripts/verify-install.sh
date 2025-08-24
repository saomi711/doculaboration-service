#!/bin/bash

# Complete installation verification script
echo "🔍 Doculaboration Installation Verification"
echo "==========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to run check
check() {
    local name="$1"
    local command="$2"
    local expected_result=${3:-0}
    
    ((TOTAL_CHECKS++))
    echo -n "Checking $name... "
    
    if eval "$command" >/dev/null 2>&1; then
        if [ $? -eq $expected_result ]; then
            echo -e "${GREEN}✓${NC}"
            ((PASSED_CHECKS++))
            return 0
        else
            echo -e "${RED}✗${NC}"
            ((FAILED_CHECKS++))
            return 1
        fi
    else
        echo -e "${RED}✗${NC}"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# Function to check file content
check_file_content() {
    local file="$1"
    local pattern="$2"
    local name="$3"
    
    ((TOTAL_CHECKS++))
    echo -n "Checking $name... "
    
    if [ -f "$file" ] && grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        ((FAILED_CHECKS++))
        return 1
    fi
}

echo -e "${BLUE}=== System Prerequisites ===${NC}"
check "Docker installation" "docker --version"
check "Docker Compose installation" "docker-compose --version"
check "Make installation" "make --version"
check "Git installation" "git --version"

echo ""
echo -e "${BLUE}=== Project Structure ===${NC}"
check "Main docker-compose.yml" "test -f docker-compose.yml"
check "Development override" "test -f docker-compose.dev.yml"
check "Production override" "test -f docker-compose.prod.yml"
check "Makefile" "test -f Makefile"
check "Main README" "test -f README.md"

echo ""
echo -e "${BLUE}=== Backend Configuration ===${NC}"
check "Backend Dockerfile" "test -f backend/Dockerfile"
check "Backend requirements" "test -f backend/requirements.txt"
check "Backend main.py" "test -f backend/app/main.py"
check "Celery configuration" "test -f backend/app/celery_app.py"

echo ""
echo -e "${BLUE}=== Frontend Configuration ===${NC}"
check "Frontend Dockerfile" "test -f frontend/Dockerfile"
check "Frontend package.json" "test -f frontend/package.json"
check "Frontend nginx config" "test -f frontend/nginx.conf"
check "Frontend environment" "test -f frontend/.env"
check "React App.tsx" "test -f frontend/src/App.tsx"
check "Document processor component" "test -f frontend/src/components/DocumentProcessor.tsx"

echo ""
echo -e "${BLUE}=== Nginx Configuration ===${NC}"
check "Nginx Dockerfile" "test -f nginx/Dockerfile"
check "Nginx main config" "test -f nginx/nginx.conf"
check "SSL template" "test -f nginx/ssl.conf"

echo ""
echo -e "${BLUE}=== Scripts ===${NC}"
check "Development script" "test -x scripts/dev.sh"
check "Production script" "test -x scripts/prod.sh"
check "Stop script" "test -x scripts/stop.sh"
check "Health check script" "test -x scripts/health-check.sh"
check "Backup script" "test -x scripts/backup.sh"
check "Restore script" "test -x scripts/restore.sh"
check "Monitor script" "test -x scripts/monitor.sh"
check "Test setup script" "test -x scripts/test-setup.sh"

echo ""
echo -e "${BLUE}=== Port Configuration ===${NC}"
check_file_content "frontend/nginx.conf" "listen 4200" "Frontend port 4200"
check_file_content "nginx/nginx.conf" "server frontend:4200" "Nginx upstream port 4200"
check_file_content "docker-compose.dev.yml" "9001:7000" "Development API port 9001"
check_file_content "frontend/.env" "REACT_APP_API_URL=/api" "Frontend API URL"

echo ""
echo -e "${BLUE}=== Docker Images Build Test ===${NC}"
echo "Building Docker images (this may take a few minutes)..."

if docker-compose build >/dev/null 2>&1; then
    echo -e "Docker build test... ${GREEN}✓${NC}"
    ((PASSED_CHECKS++))
else
    echo -e "Docker build test... ${RED}✗${NC}"
    ((FAILED_CHECKS++))
fi
((TOTAL_CHECKS++))

echo ""
echo -e "${BLUE}=== Network Connectivity ===${NC}"
check "Port 80 available" "! netstat -tuln 2>/dev/null | grep -q ':80 '"
check "Port 4200 available" "! netstat -tuln 2>/dev/null | grep -q ':4200 '"
check "Port 9001 available" "! netstat -tuln 2>/dev/null | grep -q ':9001 '"

echo ""
echo -e "${PURPLE}=== Installation Summary ===${NC}"
echo "==========================================="
echo -e "Total Checks: ${BLUE}$TOTAL_CHECKS${NC}"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 Perfect! Your Doculaboration installation is complete and ready!${NC}"
    echo ""
    echo -e "${YELLOW}Quick Start Commands:${NC}"
    echo "  make dev           # Start development environment"
    echo "  make prod          # Start production environment"
    echo "  make health        # Check service health"
    echo "  make monitor       # Start monitoring dashboard"
    echo "  make backup        # Create backup"
    echo "  make help          # Show all available commands"
    echo ""
    echo -e "${YELLOW}Access Points:${NC}"
    echo "  Development: http://localhost:4200 (frontend) + http://localhost:9001 (API)"
    echo "  Production:  http://localhost (everything through Nginx)"
    echo "  RabbitMQ:    http://localhost:15672 (guest/guest)"
    echo ""
    echo -e "${GREEN}✨ Ready to process documents!${NC}"
else
    echo ""
    echo -e "${RED}❌ Installation has issues that need to be resolved.${NC}"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  - Ensure Docker and Docker Compose are installed"
    echo "  - Check file permissions on scripts"
    echo "  - Verify port availability"
    echo "  - Review configuration files"
    echo ""
    echo "Run individual checks or consult the documentation for help."
fi

echo ""
echo -e "${BLUE}For detailed setup instructions, see:${NC}"
echo "  - README.md (Quick start guide)"
echo "  - DEPLOYMENT.md (Comprehensive deployment guide)"
echo "  - README-nginx.md (Nginx configuration details)"