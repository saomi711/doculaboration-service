# Deployment Guide

This guide covers deploying Doculaboration in different environments.

## Prerequisites

- Docker & Docker Compose
- Make (optional, for convenience commands)
- Git

## Development Deployment

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd doculaboration

# Start development environment
make dev

# In another terminal, start frontend development server
make frontend-dev
```

### Manual Development Setup
```bash
# Start backend services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Install frontend dependencies
cd frontend
npm install

# Start frontend development server
npm start
```

### Access Points (Development)
- Frontend: http://localhost:4200
- API: http://localhost:9001
- RabbitMQ: http://localhost:15672 (guest/guest)
- Redis: localhost:6379

## Production Deployment

### Quick Start
```bash
# Start production environment
make prod
```

### Manual Production Setup
```bash
# Build and start all services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

### Access Points (Production)
- Application: http://localhost
- RabbitMQ Management: http://localhost:15672 (guest/guest)

## Scaling

### Scale Workers
```bash
# Scale to 3 worker instances
make scale-workers

# Or manually
docker-compose up -d --scale worker=3
```

### Scale API Instances
```bash
# Scale API for load balancing
docker-compose up -d --scale api=2
```

## SSL/HTTPS Setup

1. **Obtain SSL certificates** (Let's Encrypt, commercial CA, etc.)

2. **Place certificates in ssl directory:**
   ```bash
   mkdir ssl
   cp your-cert.pem ssl/cert.pem
   cp your-key.pem ssl/key.pem
   ```

3. **Update nginx configuration:**
   ```bash
   # Uncomment SSL configuration in nginx/ssl.conf
   # Update domain name in the configuration
   ```

4. **Update docker-compose.yml:**
   ```yaml
   nginx:
     volumes:
       - ./ssl:/etc/nginx/ssl:ro
       - ./nginx/ssl.conf:/etc/nginx/conf.d/ssl.conf:ro
   ```

## Environment Variables

### Backend (.env)
```bash
CELERY_BROKER_URL=amqp://guest:guest@rabbitmq:5672//
CELERY_RESULT_BACKEND=redis://redis:6379/0
DEBUG=false
```

### Frontend (.env)
```bash
REACT_APP_API_URL=/api
GENERATE_SOURCEMAP=false
```

## Monitoring & Health Checks

### Health Check
```bash
make health
```

### View Logs
```bash
# All services
make logs

# Specific service
make logs-api
make logs-worker
make logs-nginx
```

### Service Status
```bash
make status
```

## Backup & Recovery

### Backup Data
```bash
# Backup Redis data
docker exec redis redis-cli BGSAVE

# Backup RabbitMQ data
docker exec rabbitmq rabbitmqctl export_definitions /tmp/definitions.json
docker cp rabbitmq:/tmp/definitions.json ./backup/

# Backup generated files
tar -czf backup/out-$(date +%Y%m%d).tar.gz out/
```

### Restore Data
```bash
# Restore RabbitMQ definitions
docker cp ./backup/definitions.json rabbitmq:/tmp/
docker exec rabbitmq rabbitmqctl import_definitions /tmp/definitions.json

# Restore generated files
tar -xzf backup/out-YYYYMMDD.tar.gz
```

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Check nginx CORS configuration
   - Verify frontend API_URL setting
   - Check browser console for details

2. **SSE Streaming Not Working**
   - Verify nginx SSE configuration
   - Check proxy buffering settings
   - Ensure proper Content-Type headers

3. **File Download Issues**
   - Check file permissions in `out/` directory
   - Verify nginx file serving configuration
   - Check backend file path generation

4. **Worker Tasks Not Processing**
   - Check RabbitMQ connection
   - Verify Celery worker logs
   - Check Redis connection

### Debug Commands
```bash
# Check container logs
docker-compose logs -f [service-name]

# Access container shell
docker-compose exec [service-name] /bin/bash

# Check network connectivity
docker network ls
docker network inspect doculaboration_default

# Check volumes
docker volume ls
docker volume inspect [volume-name]
```

## Performance Optimization

### For High Traffic
1. **Scale services:**
   ```bash
   docker-compose up -d --scale api=3 --scale worker=5
   ```

2. **Optimize nginx:**
   ```nginx
   worker_processes auto;
   worker_connections 2048;
   keepalive_timeout 65;
   ```

3. **Redis optimization:**
   ```bash
   # Add to redis configuration
   maxmemory 2gb
   maxmemory-policy allkeys-lru
   ```

### For Large Files
1. **Increase nginx limits:**
   ```nginx
   client_max_body_size 500M;
   proxy_read_timeout 300s;
   ```

2. **Optimize Docker volumes:**
   ```yaml
   volumes:
     - type: bind
       source: ./out
       target: /app/out
       bind:
         propagation: cached
   ```

## Security Considerations

1. **Change default passwords:**
   - RabbitMQ default credentials
   - Redis password (if exposed)

2. **Network security:**
   - Use Docker networks
   - Limit exposed ports
   - Configure firewall rules

3. **SSL/TLS:**
   - Enable HTTPS in production
   - Use strong SSL configuration
   - Implement HSTS headers

4. **Container security:**
   - Run containers as non-root users
   - Use minimal base images
   - Regular security updates

## Maintenance

### Regular Tasks
```bash
# Update images
docker-compose pull
docker-compose up -d

# Clean up unused resources
docker system prune -f

# Backup data (weekly)
./scripts/backup.sh

# Health check (daily)
make health
```

### Updates
```bash
# Update application
git pull
make rebuild
make prod

# Update dependencies
cd frontend && npm update
docker-compose build --no-cache
```