# 🖥️ VM Testing Guide

This guide helps you set up and test the Video Summary API in a VM environment that simulates a production server.

## 🎯 Purpose

- **Local Testing**: Test the full Docker stack without needing a real domain or SSL certificates
- **Production Simulation**: Emulate a real server environment for testing
- **CI/CD Validation**: Use this setup to test GitHub Actions workflows
- **Development**: Safe environment to experiment with configurations

## 🚀 Quick Start

### Option 1: Using the Test Script (Recommended)

```bash
# Make script executable (if not already)
chmod +x scripts/test-vm.sh

# Start all services and run tests
./scripts/test-vm.sh start

# View logs
./scripts/test-vm.sh logs

# Check status
./scripts/test-vm.sh status

# Run health checks
./scripts/test-vm.sh test

# Stop services
./scripts/test-vm.sh down
```

### Option 2: Manual Docker Compose

```bash
# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Stop services
docker compose down
```

## 🔧 Configuration

### Environment Variables

The setup requires a `backend/.env` file. If it doesn't exist, the test script will create a template:

```env
# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4

# YouTube API
YOUTUBE_API_KEY=your_youtube_api_key_here

# Azure Storage Configuration
AZURE_STORAGE_AUTH_TYPE=servicePrincipal
AZURE_STORAGE_ACCOUNT_NAME=your_storage_account
AZURE_STORAGE_CONTAINER_NAME=summary
AZURE_STORAGE_ACCOUNT_KEY=your_storage_key
AZURE_TENANT_ID=your_tenant_id
AZURE_CLIENT_ID=your_client_id
AZURE_CLIENT_SECRET=your_client_secret

# Application Configuration
MAX_FILE_SIZE=100MB
MAX_LOCAL_FILESIZE=104857600
MAX_LOCAL_FILESIZE_MB=100
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Environment
NODE_ENV=production
```

## 🌐 Available Endpoints

Once running, you can access:

| Endpoint | Description |
|----------|-------------|
| `http://localhost` | Main interface with API documentation |
| `http://localhost/health` | Nginx health check |
| `http://localhost/api/health` | Backend health check |
| `http://localhost/api/*` | All backend API endpoints |
| `http://localhost:5050` | Direct backend access (bypassing nginx) |

## 🧪 Testing Commands

### Health Checks
```bash
# Nginx health
curl http://localhost/health

# Backend health (via nginx)
curl http://localhost/api/health

# Backend health (direct)
curl http://localhost:5050/health
```

### API Testing
```bash
# Test YouTube summary (replace with actual URL)
curl -X POST "http://localhost/api/summary/youtube/streaming/summary?url=https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Check if endpoints exist
curl -s -o /dev/null -w "%{http_code}" http://localhost/api/summary/youtube/streaming/summary
```

## 🐳 Docker Services

### Backend Service
- **Image**: Custom built from `backend/Dockerfile`
- **Port**: 5050 (internal and external)
- **Environment**: Loaded from `backend/.env`
- **Volumes**: `./backend/data:/app/data`

### Nginx Service
- **Image**: `nginx:alpine`
- **Port**: 80 (HTTP only for local testing)
- **Configuration**: `./nginx/nginx.conf`
- **Purpose**: Reverse proxy and load balancer

### Network
- **Name**: `video-summary-network`
- **Type**: Bridge network for service communication

## 🔍 Troubleshooting

### Services Won't Start
```bash
# Check Docker daemon
sudo systemctl status docker

# Check compose file syntax
docker compose config

# View detailed logs
docker compose logs backend
docker compose logs nginx
```

### Environment Variable Issues
```bash
# Check if .env file exists
ls -la backend/.env

# Validate environment variables
docker compose exec backend env | grep OPENAI
```

### Network Issues
```bash
# Test backend directly
curl http://localhost:5050/health

# Check if nginx can reach backend
docker compose exec nginx curl http://backend:5050/health
```

### Port Conflicts
```bash
# Check what's using port 80
sudo netstat -tulpn | grep :80

# Use different ports if needed
docker compose up -d --scale nginx=0
docker run -p 8080:80 nginx:alpine
```

## 🚀 VM Setup Instructions

### For VirtualBox/VMware

1. **Create VM**:
   - Ubuntu 20.04+ (recommended)
   - 4GB RAM minimum
   - 20GB disk space
   - Network: NAT with port forwarding

2. **Port Forwarding**:
   - Host port 8080 → VM port 80
   - Host port 5050 → VM port 5050

3. **Install Dependencies**:
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   
   # Install Docker Compose
   sudo apt install docker-compose-plugin -y
   
   # Logout and login again
   ```

4. **Clone and Test**:
   ```bash
   git clone https://github.com/your-username/video-summary.git
   cd video-summary
   ./scripts/test-vm.sh start
   ```

5. **Access from Host**:
   - Main interface: `http://localhost:8080`
   - Backend API: `http://localhost:5050`

### For Cloud VMs (AWS, GCP, Azure)

1. **Create VM Instance**:
   - Ubuntu 20.04+
   - t3.medium or equivalent
   - Security groups: Allow ports 80, 443, 22

2. **Setup**:
   ```bash
   # SSH into VM
   ssh -i your-key.pem ubuntu@vm-ip-address
   
   # Follow same Docker installation steps
   # Clone repository and run tests
   ```

3. **Access**:
   - Use VM's public IP: `http://vm-ip-address`

## 🔄 GitHub Actions Integration

The repository includes a GitHub Actions workflow (`.github/workflows/vm-test.yml`) that:

1. **Simulates VM Environment**: Runs on Ubuntu GitHub runners
2. **Tests Docker Stack**: Builds and tests all services
3. **Validates Configuration**: Checks Docker Compose syntax
4. **Runs Health Checks**: Ensures all endpoints work
5. **Tests Script**: Validates the VM test script

### Secrets Required

Add these secrets to your GitHub repository:

- `OPENAI_API_KEY`
- `YOUTUBE_API_KEY`
- `AZURE_STORAGE_ACCOUNT_NAME`
- `AZURE_STORAGE_ACCOUNT_KEY`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

### Trigger Workflow

The workflow runs on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual trigger via GitHub UI
- Changes to backend, nginx, or Docker files

## 📊 Monitoring

### Service Health
```bash
# Check all services
docker compose ps

# Resource usage
docker stats

# Service logs
docker compose logs -f --tail=100
```

### Performance Testing
```bash
# Install apache bench
sudo apt install apache2-utils

# Test nginx performance
ab -n 1000 -c 10 http://localhost/health

# Test backend performance
ab -n 100 -c 5 http://localhost:5050/health
```

## 🔐 Security Considerations

### For Production Use

1. **Enable HTTPS**: Uncomment SSL configuration in nginx.conf
2. **Use Real Certificates**: Set up Let's Encrypt or other CA
3. **Update Security Headers**: Review and tighten CSP policies
4. **Rate Limiting**: Adjust limits based on expected traffic
5. **Firewall**: Configure iptables or cloud security groups

### For Development

- Current configuration is relaxed for easier testing
- HTTPS disabled to avoid certificate complexity
- Rate limits are permissive
- Debug headers included

## 📝 Notes

- This setup is perfect for development and testing
- For production, additional security measures are required
- The nginx configuration includes helpful API documentation
- All logs are retained for debugging
- Services have health checks and automatic restarts

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review service logs: `docker compose logs`
3. Test individual components
4. Verify environment variables
5. Check port conflicts 