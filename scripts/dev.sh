#!/bin/bash

# Development setup script
echo "🚀 Starting Doculaboration in development mode..."

# Start backend services with development overrides
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

echo "✅ Backend services started!"
echo "📊 RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo "🔧 Redis: localhost:6379"
echo "🌐 API: http://localhost:9001"
echo ""
echo "To start the frontend in development mode:"
echo "  cd frontend"
echo "  npm install"
echo "  PORT=4200 npm start  # Using port 4200 to avoid conflicts"
echo ""
echo "Frontend will be available at: http://localhost:4200"