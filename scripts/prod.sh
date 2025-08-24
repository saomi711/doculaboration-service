#!/bin/bash

# Production setup script
echo "🚀 Starting Doculaboration in production mode..."

# Build and start all services
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

echo "✅ All services started!"
echo "🌐 Application: http://localhost:9000"
echo "📊 RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo ""
echo "To scale workers:"
echo "  docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --scale worker=3"
echo ""
echo "To view logs:"
echo "  docker compose logs -f"