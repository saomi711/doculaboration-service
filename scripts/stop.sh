#!/bin/bash

# Stop all services
echo "🛑 Stopping Doculaboration services..."

docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.prod.yml down

echo "✅ All services stopped!"