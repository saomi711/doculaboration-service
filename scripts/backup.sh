#!/bin/bash

# Backup script for Doculaboration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="doculaboration_backup_$TIMESTAMP"

echo "🗄️  Creating backup: $BACKUP_NAME"
echo "=================================="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create backup subdirectory
CURRENT_BACKUP="$BACKUP_DIR/$BACKUP_NAME"
mkdir -p "$CURRENT_BACKUP"

echo "📁 Backing up configuration files..."
# Backup configuration files
cp docker-compose.yml "$CURRENT_BACKUP/"
cp docker-compose.prod.yml "$CURRENT_BACKUP/"
cp -r nginx "$CURRENT_BACKUP/"
cp -r frontend/.env* "$CURRENT_BACKUP/" 2>/dev/null || true

echo "📊 Backing up Redis data..."
# Backup Redis data
if docker ps | grep -q redis; then
    docker exec redis redis-cli BGSAVE >/dev/null 2>&1
    sleep 2
    docker cp redis:/data/dump.rdb "$CURRENT_BACKUP/redis_dump.rdb" 2>/dev/null || echo "Warning: Could not backup Redis data"
else
    echo "Warning: Redis container not running"
fi

echo "🐰 Backing up RabbitMQ configuration..."
# Backup RabbitMQ definitions
if docker ps | grep -q rabbitmq; then
    docker exec rabbitmq rabbitmqctl export_definitions /tmp/definitions.json >/dev/null 2>&1
    docker cp rabbitmq:/tmp/definitions.json "$CURRENT_BACKUP/rabbitmq_definitions.json" 2>/dev/null || echo "Warning: Could not backup RabbitMQ definitions"
else
    echo "Warning: RabbitMQ container not running"
fi

echo "📄 Backing up generated files..."
# Backup generated files
if [ -d "out" ]; then
    tar -czf "$CURRENT_BACKUP/generated_files.tar.gz" out/ 2>/dev/null || echo "Warning: Could not backup generated files"
    OUT_SIZE=$(du -sh out 2>/dev/null | cut -f1)
    echo "Generated files size: $OUT_SIZE"
else
    echo "No generated files directory found"
fi

echo "📝 Creating backup manifest..."
# Create backup manifest
cat > "$CURRENT_BACKUP/manifest.txt" << EOF
Doculaboration Backup Manifest
==============================
Backup Name: $BACKUP_NAME
Created: $(date)
Host: $(hostname)
Docker Version: $(docker --version 2>/dev/null || echo "Not available")

Contents:
- docker-compose.yml (Main configuration)
- docker-compose.prod.yml (Production overrides)
- nginx/ (Nginx configuration)
- frontend/.env* (Frontend environment files)
- redis_dump.rdb (Redis data snapshot)
- rabbitmq_definitions.json (RabbitMQ configuration)
- generated_files.tar.gz (Generated documents)

Restore Instructions:
1. Stop all services: make stop
2. Restore configuration files to project root
3. Restore Redis: docker cp redis_dump.rdb redis:/data/
4. Restore RabbitMQ: docker cp rabbitmq_definitions.json rabbitmq:/tmp/ && docker exec rabbitmq rabbitmqctl import_definitions /tmp/definitions.json
5. Restore generated files: tar -xzf generated_files.tar.gz
6. Start services: make prod
EOF

# Calculate backup size
BACKUP_SIZE=$(du -sh "$CURRENT_BACKUP" | cut -f1)

echo ""
echo "✅ Backup completed successfully!"
echo "📍 Location: $CURRENT_BACKUP"
echo "📏 Size: $BACKUP_SIZE"
echo ""

# Clean up old backups (keep last 7 days)
echo "🧹 Cleaning up old backups..."
find "$BACKUP_DIR" -name "doculaboration_backup_*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

# List current backups
echo "📋 Available backups:"
ls -la "$BACKUP_DIR" | grep doculaboration_backup_ | tail -5

echo ""
echo "💡 To restore from this backup:"
echo "   ./scripts/restore.sh $BACKUP_NAME"