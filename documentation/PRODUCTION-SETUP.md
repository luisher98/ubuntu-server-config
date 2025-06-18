# Production Setup Guide

## What Production Mode Does

Production mode provides a **secure, optimized setup** with the following key differences from development:

### 🔒 **Security Enhancements**
- **Firewall Configuration**: Only allows SSH, HTTP (80), and HTTPS (443)
- **Container Security**: Backend only binds to localhost (127.0.0.1)
- **SSL/HTTPS Support**: Ready for SSL certificate setup
- **Enhanced Security Headers**: Strict CSP, HSTS, XSS protection
- **Rate Limiting**: Stricter rate limits (30 requests/minute for API)

### 🚀 **Performance Optimizations**
- **Higher Resource Limits**: 2 CPU cores, 2GB RAM for backend
- **Optimized Nginx**: Production-grade configuration with gzip, caching
- **Better Logging**: Structured logging with rotation (50MB files, 5 files)
- **Health Checks**: Enhanced health monitoring

### 📊 **Production Features**
- **SSL Certificate Support**: Let's Encrypt integration
- **Production Logging**: Centralized logs in `/var/log/`
- **Resource Management**: Docker resource limits and reservations
- **Monitoring Ready**: Prometheus configuration available

## Quick Production Setup

### 1. Run the Setup Script
```bash
cd deployment
./setup-vm.sh -e production
```

### 2. Configure Environment Variables
The script will prompt you for:
- **OpenAI API Key**: Your OpenAI API key
- **YouTube API Key**: Your YouTube Data API key  
- **Azure Storage**: All Azure configuration (account, keys, etc.)

### 3. Start the Services
```bash
cd ~/apps/video-summary
docker compose up -d
```

### 4. Test the Setup
```bash
# Test health endpoint
curl http://localhost/health

# Test API endpoint
curl http://localhost/api/health
```

## Optional: SSL/HTTPS Setup

If you want HTTPS (recommended for production):

### 1. Get a Domain
- Purchase a domain (e.g., from Namecheap, GoDaddy)
- Point DNS A record to your server's IP address

### 2. Setup SSL Certificate
```bash
cd ~/apps/video-summary
./scripts/setup-ssl.sh -d yourdomain.com -e your@email.com
```

### 3. Deploy Production
```bash
./scripts/deploy-production.sh -d yourdomain.com
```

## Production vs Development Comparison

| Feature | Development | Production |
|---------|-------------|------------|
| **Port Binding** | All interfaces | Localhost only |
| **SSL/HTTPS** | No | Yes (optional) |
| **Firewall** | None | Strict rules |
| **Rate Limiting** | 10 req/sec | 30 req/minute |
| **Resource Limits** | 1 CPU, 1GB RAM | 2 CPU, 2GB RAM |
| **Logging** | Basic | Structured + rotation |
| **Security Headers** | Basic | Enhanced |
| **Health Checks** | Basic | Advanced |

## Production Configuration Files

### Docker Compose
- **Development**: `docker-compose.development.yml`
- **Production**: `docker-compose.prod.yml`

### Nginx
- **Development**: `nginx/nginx.dev.conf`
- **Production**: `nginx/nginx.prod.conf`

### Environment Files
- **Development**: `backend/.env`
- **Production**: `backend/.env.prod`

## Monitoring and Maintenance

### View Logs
```bash
# Application logs
docker logs video-summary-backend-1

# Nginx logs
docker logs video-summary-nginx-1

# System logs
tail -f /var/log/video-summary/*.log
```

### Resource Usage
```bash
# Docker resource usage
docker stats

# System resource usage
htop
```

### SSL Certificate Renewal
```bash
# Manual renewal
cd ~/apps/video-summary
docker compose run --rm certbot renew

# Automatic renewal (add to crontab)
0 12 * * * /home/user/apps/video-summary/scripts/renew-ssl.sh
```

## Troubleshooting

### Common Issues

1. **Port 80/443 not accessible**
   - Check firewall: `sudo ufw status`
   - Ensure ports are open: `sudo ufw allow 80` and `sudo ufw allow 443`

2. **Backend not responding**
   - Check logs: `docker logs video-summary-backend-1`
   - Verify environment variables in `backend/.env.prod`

3. **SSL certificate issues**
   - Check domain DNS: `nslookup yourdomain.com`
   - Verify certbot logs: `docker logs video-summary-certbot-1`

### Performance Tuning

1. **Increase Resources** (if needed)
   - Edit `docker-compose.yml` and increase CPU/memory limits

2. **Optimize Nginx**
   - Adjust worker processes in `nginx/nginx.prod.conf`
   - Tune rate limiting based on your traffic

3. **Database Optimization** (if using external database)
   - Configure connection pooling
   - Set appropriate timeouts

## Security Checklist

- [ ] Firewall configured (UFW enabled)
- [ ] Backend only accessible via nginx
- [ ] SSL certificate installed (if using HTTPS)
- [ ] Environment variables secured (600 permissions)
- [ ] Regular security updates applied
- [ ] Monitoring and alerting configured
- [ ] Backup strategy implemented

## Next Steps

1. **Basic Production**: Run setup and start services
2. **SSL Setup**: Add domain and SSL certificate
3. **Monitoring**: Set up monitoring and alerting
4. **Backup**: Implement backup strategy
5. **Scaling**: Consider load balancing for high traffic

The production setup is now simplified and focuses on the essential security and performance features without unnecessary complexity! 