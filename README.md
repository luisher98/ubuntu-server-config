# Ubuntu Server Configuration

This repository contains scripts and configurations for setting up and deploying a video summary application on Ubuntu 22.04 LTS or later. It supports both **development** and **production** environments with different configurations optimized for each use case.

## 🌟 Features

### Development Environment
- **Backend-only setup** for rapid development and testing
- HTTP-only access (no SSL complexity)
- Relaxed security settings for easier debugging
- Development-friendly nginx configuration with API documentation
- Automatic installation of yt-dlp and ffmpeg for video processing

### Production Environment
- **Full production setup** with SSL certificates and security hardening
- HTTPS with Let's Encrypt SSL certificates
- Production-grade nginx configuration with security headers
- Rate limiting and DDoS protection
- Automated backup and deployment scripts
- Monitoring and health checks
- Firewall configuration

## 📋 Prerequisites

- **OS**: Ubuntu 20.04 LTS or newer
- **RAM**: 2GB minimum (4GB recommended for production)
- **Storage**: 10GB minimum (20GB+ recommended for production)
- **Network**: Internet connection and appropriate firewall ports
- **Permissions**: User with sudo privileges

### For Production Additionally:
- **Domain name** pointing to your server's IP address
- **Email address** for SSL certificate notifications

## 🚀 Quick Start

### Option 1: Interactive Setup (Recommended)
```bash
cd && rm -rf ~/apps ~/backend ~/frontend ~/ubuntu-server-config && mkdir -p ~/apps && git clone https://github.com/luisher98/ubuntu-server-config.git ~/apps/deployment && cd ~/apps/deployment && chmod +x setup-vm.sh && ./setup-vm.sh
```

### Option 2: Direct Environment Selection
```bash
# For development environment
./setup-vm.sh -e development

# For production environment  
./setup-vm.sh -e production

# Skip environment variable configuration
./setup-vm.sh -e development --skip-env-config
```

## 📁 Directory Structure

After setup, the following directory structure is created:

```
~/apps/
├── deployment/              # Contains deployment scripts and configurations
│   ├── setup-vm.sh         # Main setup script
│   ├── docker-compose.development.yml  # Development template
│   ├── docker-compose.prod.yml         # Production template
│   ├── nginx/
│   │   ├── nginx.dev.conf  # Development nginx template
│   │   ├── nginx.prod.conf # Production nginx template
│   │   └── certbot/        # SSL certificate storage
│   └── scripts/
│       ├── setup-ssl.sh    # SSL certificate setup
│       ├── deploy-production.sh
│       ├── backup.sh
│       └── test-vm.sh
└── video-summary/          # Main application directory
    ├── backend/            # Backend application (cloned from git)
    ├── frontend/           # Frontend application (cloned from git)
    ├── nginx/              # Nginx configuration
    │   └── nginx.conf      # Environment-specific nginx config
    ├── scripts/            # Deployment and utility scripts
    ├── docker-compose.yml  # Environment-specific compose file
    └── .env files          # Environment-specific configurations
```

## 🛠️ Environment Configurations

### Development Environment

**Purpose**: Backend development and API testing

**Features**:
- Backend service only (frontend commented out)
- HTTP access on port 80
- Development nginx config with API documentation page
- Relaxed rate limiting
- Volume mounting for live development
- Includes yt-dlp and ffmpeg for video processing

**Access**:
- API Base: `http://localhost`
- Health Check: `http://localhost/health`
- API Endpoints: `http://localhost/api/*`
- Backend Direct: `http://localhost:5050`

**Configuration Files**:
- `docker-compose.yml` (contains development-specific settings)
- `nginx/nginx.conf` (development nginx configuration)
- `backend/.env`

### Production Environment

**Purpose**: Production deployment with security and monitoring

**Features**:
- HTTPS with Let's Encrypt SSL certificates
- Security headers and rate limiting
- Production logging and monitoring
- Backup and rollback capabilities
- Firewall configuration
- Automated deployment scripts

**Access**:
- HTTPS Site: `https://yourdomain.com`
- Health Check: `https://yourdomain.com/health`
- API Endpoints: `https://yourdomain.com/api/*`

**Configuration Files**:
- `docker-compose.yml` (contains production-specific settings)
- `nginx/nginx.conf` (production nginx configuration)
- `backend/.env.prod`

## 🔧 Setup Process

### 1. Environment Selection

The setup script will prompt you to choose:

```
1) Development  - Backend-only setup for development and testing
                 - HTTP only (no SSL)
                 - Relaxed security settings
                 - Development tools included

2) Production   - Full production setup with SSL and security
                 - HTTPS with Let's Encrypt SSL
                 - Security hardening enabled
                 - Production monitoring
```

### 2. Package Installation

The script automatically installs:
- **Node.js 20.x** with npm and TypeScript
- **Docker** and Docker Compose
- **Python 3** with virtual environment
- **yt-dlp** and **youtube-dl** for video downloading
- **ffmpeg** for video processing
- Additional utilities: git, curl, wget, htop, net-tools

### 3. Application Setup

- Clones backend and frontend repositories
- Creates appropriate environment files
- Sets up nginx configuration for chosen environment
- Copies deployment scripts and documentation
- Configures directory permissions

### 4. Environment-Specific Configuration

**Development**:
- Creates `.env` file for backend
- Sets up development docker-compose configuration
- Configures development nginx with API docs

**Production**:
- Creates `.env.prod` file for backend
- Sets up production docker-compose with SSL
- Configures firewall rules (UFW)
- Creates log directories
- Provides next steps for SSL setup

## 🚀 Starting the Application

### Development Environment

```bash
# Navigate to application directory
cd ~/apps/video-summary

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Access the application
curl http://localhost/health
```

### Production Environment

```bash
# Navigate to application directory
cd ~/apps/video-summary

# 1. Update production environment variables
sudo nano backend/.env.prod

# 2. Set up SSL certificates
sudo ./scripts/setup-ssl.sh -d yourdomain.com -e your@email.com

# 3. Deploy to production
sudo ./scripts/deploy-production.sh -d yourdomain.com

# 4. Check status
docker compose ps
```

## 🔐 Production Security Features

### SSL/TLS Configuration
- **Let's Encrypt** certificates with automatic renewal
- **TLS 1.2 and 1.3** with secure cipher suites
- **HSTS** headers for forced HTTPS
- **SSL stapling** for improved performance

### Security Headers
- Content Security Policy (CSP)
- X-Frame-Options (prevent clickjacking)
- X-Content-Type-Options (prevent MIME sniffing)
- X-XSS-Protection
- Referrer Policy

### Rate Limiting
- **API endpoints**: 30 requests per minute
- **Auth endpoints**: 5 requests per minute  
- **Static content**: 10 requests per second
- **Connection limits**: 50 concurrent connections per IP

### Network Security
- Backend only accessible via localhost
- UFW firewall with minimal open ports
- Nginx reverse proxy with security filtering

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# System health
curl https://yourdomain.com/health

# API health
curl https://yourdomain.com/api/health

# Docker service status
docker compose ps
```

### Log Management

```bash
# Application logs
docker compose logs backend
docker compose logs nginx

# System logs
sudo tail -f /var/log/video-summary/*.log
sudo tail -f /var/log/nginx/access.log
```

### Backup & Recovery

```bash
# Manual backup
sudo ./scripts/backup.sh

# View backup status
ls -la /var/backups/video-summary/

# Rollback (if needed during deployment)
sudo ./scripts/deploy-production.sh --rollback
```

## 🛠️ Available Scripts

### Core Scripts
- `setup-vm.sh` - Main setup script with environment selection
- `scripts/setup-ssl.sh` - SSL certificate setup with Let's Encrypt
- `scripts/deploy-production.sh` - Production deployment with rollback
- `scripts/backup.sh` - Backup application data and configuration
- `scripts/test-vm.sh` - VM testing and validation

### Script Usage Examples

```bash
# SSL setup
sudo ./scripts/setup-ssl.sh -d api.example.com -e admin@example.com

# Production deployment
sudo ./scripts/deploy-production.sh -d api.example.com

# Backup
sudo ./scripts/backup.sh

# Testing
./scripts/test-vm.sh
```

## 🔧 Configuration Files

### Backend Environment Variables

**Development** (`.env`):
```env
OPENAI_API_KEY=your-dev-key
OPENAI_MODEL=gpt-3.5-turbo
YOUTUBE_API_KEY=your-youtube-key
# ... other configuration
```

**Production** (`.env.prod`):
```env
OPENAI_API_KEY=your-production-key
OPENAI_MODEL=gpt-4
NODE_ENV=production
ADMIN_EMAIL=admin@yourdomain.com
DOMAIN=yourdomain.com
# ... enhanced production configuration
```

**Configuration Files**:
- `docker-compose.yml` (contains development-specific settings)
- `nginx/nginx.conf` (development nginx configuration)
- `backend/.env`

### Production Environment

**Purpose**: Production deployment with security and monitoring

**Features**:
- HTTPS with Let's Encrypt SSL certificates
- Security headers and rate limiting
- Production logging and monitoring
- Backup and rollback capabilities
- Firewall configuration
- Automated deployment scripts

**Access**:
- HTTPS Site: `https://yourdomain.com`
- Health Check: `https://yourdomain.com/health`
- API Endpoints: `https://yourdomain.com/api/*`

**Configuration Files**:
- `docker-compose.yml` (contains production-specific settings)
- `nginx/nginx.conf` (production nginx configuration)
- `backend/.env.prod`

## 🚨 Troubleshooting

### Common Issues

#### Development Environment
```bash
# Port 80 already in use
sudo lsof -i :80
sudo systemctl stop apache2  # if Apache is running

# Docker permission issues
sudo usermod -aG docker $USER
# Then logout and login again

# Backend not responding
docker compose logs backend
curl http://localhost:5050/health
```

#### Production Environment
```bash
# SSL certificate issues
sudo ./scripts/setup-ssl.sh -d yourdomain.com -e your@email.com --staging

# Check DNS resolution
dig yourdomain.com

# Check certificate status
sudo openssl x509 -in ~/apps/video-summary/nginx/certbot/conf/live/yourdomain.com/fullchain.pem -text -noout
```

### Getting Help

1. **Check logs**: `docker compose logs`
2. **Verify configuration**: `docker compose config`
3. **Test connectivity**: Health check endpoints
4. **Review documentation**: `PRODUCTION-DEPLOYMENT.md`

## 📚 Documentation

- `PRODUCTION-DEPLOYMENT.md` - Detailed production deployment guide
- `VM-TESTING.md` - VM testing and validation procedures
- Backend API documentation available at development nginx welcome page

## 🔄 Updates and Maintenance

### Updating the Application

```bash
# Development
cd ~/apps/video-summary
git pull  # Update configuration if needed
docker compose down && docker compose up -d --build

# Production
sudo ./scripts/deploy-production.sh -d yourdomain.com
```

### SSL Certificate Renewal

Automatic renewal is configured via cron. Manual renewal:
```bash
sudo ./scripts/renew-ssl.sh
```

## 📞 Support

For issues, feature requests, or contributions:
1. Check the troubleshooting section above
2. Review the detailed documentation in `PRODUCTION-DEPLOYMENT.md`
3. Check Docker logs and system status
4. Ensure all prerequisites are met

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🎯 Quick Reference

### Essential Commands

**Development**:
```bash
cd ~/apps/video-summary
docker compose up -d                    # Start services
docker compose down                     # Stop services
docker compose logs -f                  # View logs
curl http://localhost/health           # Health check
```

**Production**:
```bash
cd ~/apps/video-summary
docker compose up -d                        # Start services
docker compose down                         # Stop services
docker compose logs -f                      # View logs
sudo ./scripts/deploy-production.sh -d yourdomain.com    # Deploy updates
curl https://yourdomain.com/health                       # Health check
```

Remember to replace `yourdomain.com` with your actual domain name!