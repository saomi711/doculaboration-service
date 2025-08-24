#!/bin/bash

# Restore script for Doculaboration
BACKUP_DIR="./backups"

if [ -z "$1" ]; then
    echo "❌ Usage: $0 <backup_name>"
    echo ""
    echo "Available backups:"
    ls -la "$BACKUP_DIR" | grep doculaboration_backup_ | tail -10
    exit 1
fi

BACKUP_NAME="$1"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

if [ ! -d "$BACKUP_PATH" ]; then
    echo "❌ Backup not found: $BACKUP_PATH"
    exit 1
fi

echo "🔄 Restoring from backup: $BACKUP_NAME"
echo "======================================"

# Show backup manifest
if [ -f "$BACKUP_PATH/manifest.txt" ]; then
    echo "📋 Backup manifest:"
    cat "$BACKUP_PATH/manifest.txt"
    echo ""
fi

# Confirm restore
read -p "⚠️  This will overwrite current configuration. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

echo "🛑 Stopping current services..."
make stop >/dev/null 2>&1

echo "📁 Restoring configuration files..."
# Restore configuration files
cp "$BACKUP_PATH/docker-compose.yml" . 2>/dev/null || echo "Warning: docker-compose.yml not found in backup"
cp "$BACKUP_PATH/docker-compose.prod.yml" . 2>/dev/null || echo "Warning: docker-compose.prod.yml not found in backup"

if [ -d "$BACKUP_PATH/nginx" ]; then
    cp -r "$BACKUP_PATH/nginx" . 2>/dev/null || echo "Warning: Could not restore nginx configuration"
fi

# Restore frontend env files
cp "$BACKUP_PATH/.env"* frontend/ 2>/dev/null || echo "Warning: Could not restore frontend environment files"

echo "🚀 Starting services..."
make prod >/dev/null 2>&1
sleep 10

echo "📊 Restoring Redis data..."
# Restore Redis data
if [ -f "$BACKUP_PATH/redis_dump.rdb" ]; then
    docker cp "$BACKUP_PATH/redis_dump.rdb" redis:/data/dump.rdb 2>/dev/null || echo "Warning: Could not restore Redis data"
    docker restart redis >/dev/null 2>&1
else
    echo "Warning: Redis backup not found"
fi

echo "🐰 Restoring RabbitMQ configuration..."
# Restore RabbitMQ definitions
if [ -f "$BACKUP_PATH/rabbitmq_definitions.json" ]; then
    docker cp "$BACKUP_PATH/rabbitmq_definitions.json" rabbitmq:/tmp/definitions.json 2>/dev/null || echo "Warning: Could not copy RabbitMQ definitions"
    docker exec rabbitmq rabbitmqctl import_definitions /tmp/definitions.json >/dev/null 2>&1 || echo "Warning: Could not import RabbitMQ definitions"
else
    echo "Warning: RabbitMQ backup not found"
fi

echo "📄 Restoring generated files..."
# Restore generated files
if [ -f "$BACKUP_PATH/generated_files.tar.gz" ]; then
    tar -xzf "$BACKUP_PATH/generated_files.tar.gz" 2>/dev/null || echo "Warning: Could not restore generated files"
else
    echo "Warning: Generated files backup not found"
fi

echo ""
echo "✅ Restore completed!"
echo ""
echo "🔍 Running health check..."
sleep 5
make health

echo ""
echo "💡 If there are issues, check the logs:"
echo "   make logs"