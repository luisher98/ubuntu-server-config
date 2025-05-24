# 🚀 Production Deployment Guide

This guide covers deploying the Video Summary API to production with SSL certificates, security hardening, and monitoring.

## 📋 Prerequisites

### Server Requirements
- **OS**: Ubuntu 20.04 LTS or newer (recommended)
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB minimum, 50GB recommended
- **CPU**: 2 cores minimum, 4 cores recommended
- **Network**: Public IP address with ports 80, 443, and 22 open

### Domain Requirements
- **Domain Name**: A registered domain (e.g., `api.yourdomain.com`)
- **DNS Configuration**: A record pointing to your server's IP address
- **Email**: Valid email for Let's Encrypt notifications

### Software Requirements
- Docker 20.10+
- Docker Compose 2.0+
- Git
- curl, wget, openssl
- Root or sudo access

## 🛠️ Installation Steps

### Step 1: Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git openssl net-tools

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Logout and login again to apply group changes
```

### Step 2: Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-username/video-summary.git
cd video-summary

# Make scripts executable
chmod +x scripts/*.sh
```

### Step 3: SSL Certificate Setup

```bash
# Set up SSL certificates with Let's Encrypt
sudo ./scripts/setup-ssl.sh -d your-domain.com -e your-email@domain.com

# For testing with staging certificates (optional)
sudo ./scripts/setup-ssl.sh -d your-domain.com -e your-email@domain.com --staging
```

### Step 4: Configure Environment

Edit the production environment file:

```bash
sudo nano backend/.env.prod
```

Update all values:

```env
# OpenAI Configuration
OPENAI_API_KEY=sk-your-real-openai-key
OPENAI_MODEL=gpt-4

# YouTube API (get from Google Cloud Console)
YOUTUBE_API_KEY=your-youtube-api-key

# Azure Storage Configuration
AZURE_STORAGE_AUTH_TYPE=servicePrincipal
AZURE_STORAGE_ACCOUNT_NAME=your-storage-account
AZURE_STORAGE_CONTAINER_NAME=summary
AZURE_STORAGE_ACCOUNT_KEY=your-storage-key
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret

# Application Configuration
MAX_FILE_SIZE=100MB
MAX_LOCAL_FILESIZE=104857600
MAX_LOCAL_FILESIZE_MB=100
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=50

# Environment
NODE_ENV=production

# Admin Configuration
ADMIN_EMAIL=your-email@domain.com
DOMAIN=your-domain.com
```

### Step 5: Deploy to Production

```bash
# Run production deployment
sudo ./scripts/deploy-production.sh -d your-domain.com

# Or test with dry-run first
sudo ./scripts/deploy-production.sh -d your-domain.com --dry-run
```

## 🔒 Security Configuration

### Firewall Setup

```bash
# Install and configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### SSL Security Headers

The production nginx configuration includes:

- **HSTS**: Force HTTPS connections
- **CSP**: Content Security Policy
- **XSS Protection**: Cross-site scripting protection
- **MIME Type Sniffing**: Prevent MIME type confusion
- **Frame Options**: Prevent clickjacking

### Rate Limiting

Production rate limits:
- **API endpoints**: 30 requests per minute
- **Auth endpoints**: 5 requests per minute
- **Static content**: 10 requests per second

### Environment Security

- Environment variables are loaded from secure `.env.prod` file
- Backend only listens on localhost (proxied through nginx)
- All logs are properly configured and rotated
- Automatic security updates recommended

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Check service status
sudo docker compose -f docker-compose.prod.yml ps

# Check logs
sudo docker compose -f docker-compose.prod.yml logs

# Health check endpoints
curl https://your-domain.com/health
curl https://your-domain.com/api/health
```

### SSL Certificate Renewal

Automatic renewal is set up via cron:

```bash
# Add to crontab for automatic renewal
sudo crontab -e

# Add this line:
0 12 * * * /path/to/video-summary/scripts/renew-ssl.sh >> /var/log/letsencrypt-renew.log 2>&1
```

### Log Management

Logs are automatically rotated and stored in:
- `/var/log/nginx/` - Nginx access and error logs
- `/var/log/video-summary/` - Application logs
- Docker container logs via `docker logs`

### Backup Strategy

```bash
# Manual backup
sudo mkdir -p /var/backups/video-summary
sudo cp -r backend/data /var/backups/video-summary/data-$(date +%Y%m%d)
sudo cp backend/.env.prod /var/backups/video-summary/env-$(date +%Y%m%d)

# Automated backup (add to crontab)
0 2 * * * /path/to/video-summary/scripts/backup.sh
```

### Resource Monitoring

```bash
# Check resource usage
sudo docker stats

# Check disk usage
df -h

# Check memory usage
free -h

# Check system load
top
```

## 🔧 Configuration Files

### Key Production Files

- `docker-compose.prod.yml` - Production Docker Compose configuration
- `nginx/nginx.prod.conf` - Production Nginx configuration
- `backend/.env.prod` - Production environment variables
- `scripts/setup-ssl.sh` - SSL certificate setup script
- `scripts/deploy-production.sh` - Production deployment script
- `scripts/renew-ssl.sh` - SSL certificate renewal script

### File Permissions

```bash
# Set correct permissions
sudo chown -R root:docker nginx/
sudo chmod 755 nginx/certbot/conf
sudo chmod 755 nginx/certbot/www
sudo chmod 600 backend/.env.prod
sudo chmod +x scripts/*.sh
```

## 🚨 Troubleshooting

### Common Issues

#### SSL Certificate Problems

```bash
# Check certificate status
sudo openssl x509 -in nginx/certbot/conf/live/your-domain.com/fullchain.pem -text -noout

# Renew certificate manually
sudo docker compose -f docker-compose.prod.yml run --rm certbot renew

# Check DNS resolution
dig your-domain.com
```

#### Service Health Issues

```bash
# Check backend logs
sudo docker compose -f docker-compose.prod.yml logs backend

# Check nginx logs
sudo docker compose -f docker-compose.prod.yml logs nginx

# Test backend directly
curl http://localhost:5050/health

# Test nginx config
sudo docker compose -f docker-compose.prod.yml exec nginx nginx -t
```

#### Performance Issues

```bash
# Check resource usage
sudo docker stats --no-stream

# Check disk space
df -h

# Check system load
htop

# Scale services if needed
sudo docker compose -f docker-compose.prod.yml up -d --scale backend=2
```

### Recovery Procedures

#### Rollback Deployment

```bash
# Automatic rollback (triggered on deployment failure)
# Manual rollback
sudo ./scripts/deploy-production.sh --rollback

# Or restore from backup
sudo cp /var/backups/video-summary/env-YYYYMMDD backend/.env.prod
sudo docker compose -f docker-compose.prod.yml up -d
```

#### Restore SSL Certificates

```bash
# Re-run SSL setup
sudo ./scripts/setup-ssl.sh -d your-domain.com -e your-email@domain.com

# Or restore from backup
sudo cp -r /var/backups/letsencrypt/* nginx/certbot/conf/
```

## 📈 Scaling & Optimization

### Horizontal Scaling

```bash
# Scale backend services
sudo docker compose -f docker-compose.prod.yml up -d --scale backend=3

# Use load balancer (nginx automatically handles this)
```

### Performance Optimization

```yaml
# In docker-compose.prod.yml, adjust resources:
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 4G
    reservations:
      cpus: '2'
      memory: 2G
```

### Database Optimization

```bash
# Add Redis for caching (optional)
# Add PostgreSQL for persistent data (optional)
# Configure connection pooling
```

## 🔄 CI/CD Integration

### GitHub Actions Deployment

```yaml
# Add to .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to server
        run: |
          ssh -i ${{ secrets.SSH_KEY }} user@your-server.com 'cd /path/to/video-summary && git pull && sudo ./scripts/deploy-production.sh -d your-domain.com'
```

### Automated Testing

```bash
# Run tests before deployment
npm test
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

## 📚 Additional Resources

### Security Best Practices

1. **Regular Updates**: Keep system and dependencies updated
2. **Access Control**: Use SSH keys, disable password authentication
3. **Monitoring**: Set up alerting for failures and security events
4. **Backups**: Regular automated backups with offsite storage
5. **Secrets Management**: Use proper secret management tools

### Performance Monitoring

1. **APM Tools**: Consider using tools like New Relic, DataDog
2. **Log Aggregation**: ELK stack, Fluentd, or similar
3. **Metrics**: Prometheus + Grafana for detailed metrics
4. **Alerting**: PagerDuty, Slack notifications for critical issues

### Compliance & Governance

1. **Data Privacy**: GDPR, CCPA compliance if applicable
2. **API Security**: Rate limiting, authentication, authorization
3. **Audit Logging**: Comprehensive request/response logging
4. **Incident Response**: Documented procedures for security incidents

## 📞 Support

### Emergency Contacts

- **Primary Admin**: your-email@domain.com
- **Hosting Provider**: Contact information
- **Domain Registrar**: Contact information

### Status Page

Consider setting up a status page to communicate service availability:
- **Internal**: Simple HTML page served by nginx
- **External**: Services like StatusPage.io or custom solution

---

## 🎯 Quick Reference

### Essential Commands

```bash
# Start services
sudo docker compose -f docker-compose.prod.yml up -d

# Stop services
sudo docker compose -f docker-compose.prod.yml down

# View logs
sudo docker compose -f docker-compose.prod.yml logs -f

# Check status
sudo docker compose -f docker-compose.prod.yml ps

# Renew SSL
sudo ./scripts/renew-ssl.sh

# Deploy updates
sudo ./scripts/deploy-production.sh -d your-domain.com

# Backup data
sudo cp -r backend/data /var/backups/video-summary/
```

### URLs to Monitor

- `https://your-domain.com/health` - Main health check
- `https://your-domain.com/api/health` - API health check
- `https://your-domain.com` - Main interface

### Important Files to Monitor

- `/var/log/nginx/error.log` - Nginx errors
- `/var/log/video-summary/` - Application logs
- `backend/.env.prod` - Environment configuration
- `nginx/certbot/conf/live/your-domain.com/` - SSL certificates

Remember to replace `your-domain.com` and other placeholders with your actual values throughout this guide! 