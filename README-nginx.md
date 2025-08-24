# Nginx Configuration for Doculaboration

This document explains the Nginx setup for the Doculaboration project.

## Architecture

```
Internet → Nginx (Port 80) → Frontend (Port 4200)
                           → Backend API (Port 9001)
```

## Features

### 🔄 Reverse Proxy
- Routes `/api/*` requests to the FastAPI backend
- Routes all other requests to the React frontend
- Removes `/api` prefix when forwarding to backend

### ⚖️ Load Balancing
- Ready for multiple backend instances
- Round-robin load balancing
- Health checks for backend services

### 🚀 Performance Optimizations
- Gzip compression for text content
- Static file caching with proper headers
- Connection keep-alive
- Buffering optimizations

### 🔒 Security Headers
- X-Frame-Options: SAMEORIGIN
- X-XSS-Protection: 1; mode=block
- X-Content-Type-Options: nosniff
- Content-Security-Policy
- Referrer-Policy

### 📡 Server-Sent Events (SSE)
- Special handling for `/api/stream/*` endpoints
- Disabled buffering for real-time streaming
- Extended timeout for long-running streams

## Usage

### Development Mode
```bash
# Start with direct API access
make dev

# Or manually
./scripts/dev.sh
```

### Production Mode
```bash
# Start with Nginx proxy
make prod

# Or manually
./scripts/prod.sh
```

### Scaling Backend
```bash
# Scale API instances for load balancing
docker-compose up -d --scale api=3

# Scale workers
docker-compose up -d --scale worker=5
```

## Configuration Files

- `nginx/nginx.conf` - Main Nginx configuration
- `nginx/Dockerfile` - Nginx container build
- `nginx/ssl.conf` - SSL configuration template
- `frontend/nginx.conf` - Frontend-specific Nginx config

## Endpoints

| Path | Destination | Purpose |
|------|-------------|---------|
| `/` | Frontend | React app |
| `/api/*` | Backend | API requests |
| `/api/stream/*` | Backend | Server-sent events |
| `/health` | Nginx | Health check |

## SSL/HTTPS Setup

To enable HTTPS:

1. Obtain SSL certificates
2. Place them in `./ssl/` directory
3. Uncomment SSL configuration in `nginx/ssl.conf`
4. Update docker-compose to mount SSL volume

## Monitoring

### Health Checks
- Nginx health: `http://localhost/health`
- Backend health: `http://localhost/api/health`

### Logs
```bash
# All services
make logs

# Nginx only
make logs-nginx

# API only
make logs-api
```

## Troubleshooting

### CORS Issues
- Nginx handles CORS headers as backup
- Backend should handle CORS primarily
- Check browser console for preflight errors

### SSE Not Working
- Verify `/api/stream/*` location block
- Check proxy buffering is disabled
- Ensure proper Content-Type headers

### Load Balancing Issues
- Check upstream backend health
- Verify backend instances are running
- Review nginx error logs

## Performance Tuning

### For High Traffic
```nginx
# Add to nginx.conf
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
client_max_body_size 100M;
```

### For Many Concurrent Connections
```nginx
# Increase worker connections
events {
    worker_connections 2048;
    use epoll;
}
```