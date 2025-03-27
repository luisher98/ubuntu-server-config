# Video-To-Summary Deployment

This repository contains deployment configuration for the video-to-summary application stack.

## Components

- **Backend**: Express.js + TypeScript application ([source](https://github.com/luisher98/video-to-summary))
- **Frontend**: Next.js web application ([source](https://github.com/luisher98/video-to-summary-app))
- **Nginx**: Reverse proxy with security headers and optimized configuration
- **Docker**: Containerized deployment with health checks and security best practices

## Quick Start Guide

If you're setting up on a fresh Ubuntu VM, here are the quick commands to get everything running:

```bash
# 1. Clone the deployment repository
git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/apps/video-summary/deployment

# 2. Run the VM setup script (this will install Docker, create directories, and clone repositories)
cd /home/ubuntu/apps/video-summary/deployment
./setup-vm.sh

# 3. Log out and log back in for Docker group changes to take effect
exit
# Log back in to your VM

# 4. Set up environment variables
cd /home/ubuntu/apps/video-summary/deployment
./setup-env.sh

cd /home/ubuntu/apps/video-summary/backend
./setup-backend-env.sh

cd /home/ubuntu/apps/video-summary/frontend
./setup-frontend-env.sh

# 5. Start services
cd /home/ubuntu/apps/video-summary/deployment
docker compose up -d

# 6. Test deployment
./test-deployment.sh
```

The application will be available at:
- Frontend: http://localhost
- Backend API: http://localhost/api

Useful commands:
```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Rebuild after changes
docker compose up -d --build
```

For detailed setup instructions and troubleshooting, continue reading below.

## Server Setup

The deployment assumes the following folder structure on the server:

```
/home/ubuntu/
  └── apps/
      └── video-summary/
          ├── backend/           # Backend code (already cloned)
          ├── frontend/          # Frontend code (already cloned)
          └── deployment/        # This repo
              ├── docker-compose.yml
              ├── backend.Dockerfile
              ├── frontend.Dockerfile
              ├── nginx.conf
              ├── frontend-nginx.conf
              ├── setup-env.sh
              ├── setup-backend-env.sh
              ├── setup-frontend-env.sh
              ├── setup-vm.sh
              ├── test-deployment.sh
              └── .github/workflows/
                  ├── deploy-backend.yml
                  └── deploy-frontend.yml
```

## Initial Deployment

1. Clone the backend and frontend repositories:
   ```bash
   git clone https://github.com/luisher98/video-to-summary.git /home/ubuntu/apps/video-summary/backend
   git clone https://github.com/luisher98/video-to-summary-app.git /home/ubuntu/apps/video-summary/frontend
   ```

2. Clone this deployment repository:
   ```bash
   git clone <this-repo-url> /home/ubuntu/apps/video-summary/deployment
   ```

3. Set up environment variables:
   ```bash
   # Main deployment environment
   cd /home/ubuntu/apps/video-summary/deployment
   ./setup-env.sh
   
   # Backend environment
   cd /home/ubuntu/apps/video-summary/backend
   ./setup-backend-env.sh
   
   # Frontend environment
   cd /home/ubuntu/apps/video-summary/frontend
   ./setup-frontend-env.sh
   ```

4. Copy the frontend nginx config to the frontend repo:
   ```bash
   cp /home/ubuntu/apps/video-summary/deployment/frontend-nginx.conf /home/ubuntu/apps/video-summary/frontend/nginx.conf
   ```

5. Build and start all services:
   ```bash
   cd /home/ubuntu/apps/video-summary/deployment
   docker compose up -d
   ```

## Security Features

- All containers run as non-root users
- Nginx configured with security headers:
  - X-Content-Type-Options
  - X-XSS-Protection
  - X-Frame-Options
  - Referrer-Policy
  - Content-Security-Policy
  - Strict-Transport-Security
- Environment variables with validation
- Secure file permissions (600) for .env files
- No direct exposure of internal ports
- Rate limiting configured:
  - API endpoints: 10 requests/second
  - Static content: 100 requests/second
- Input validation for API keys and connection strings

## Performance Optimization

- Gzip compression enabled for static files
- Proxy buffering configured for better performance
- Optimized Nginx configuration for static file serving
- Resource limits for containers:
  - Backend: 1 CPU, 1GB RAM
  - Frontend: 0.5 CPU, 512MB RAM
  - Nginx: 0.5 CPU, 256MB RAM
- Health checks to ensure service availability
- Log rotation to prevent disk space issues

## Monitoring and Health Checks

All services include health checks:
- Backend: Checks `/health` endpoint
- Frontend: Checks root endpoint
- Nginx: Validates configuration

To check service status:
```bash
docker compose ps
```

To view logs:
```bash
docker compose logs -f [service_name]
```

## Logging

- Access logs: `/var/log/nginx/access.log`
- Error logs: `/var/log/nginx/error.log`
- Frontend access logs: `/var/log/nginx/frontend_access.log`
- Frontend error logs: `/var/log/nginx/frontend_error.log`

Log rotation is configured to prevent disk space issues:
- Max log size: 10MB
- Max number of rotated logs: 3

## CI/CD Setup

1. In your GitHub repository settings, add the following secrets:
   - `SERVER_IP`: Your server's IP address
   - `SSH_PRIVATE_KEY`: SSH private key for the ubuntu user

2. Push changes to the main branch to trigger automatic deployments.

## Manual Deployment

To manually deploy updates:

1. Pull the latest code for the backend/frontend:
   ```bash
   cd /home/ubuntu/apps/video-summary/backend && git pull
   cd /home/ubuntu/apps/video-summary/frontend && git pull
   ```

2. Pull the latest deployment configuration:
   ```bash
   cd /home/ubuntu/apps/video-summary/deployment && git pull
   ```

3. Rebuild and restart services:
   ```bash
   cd /home/ubuntu/apps/video-summary/deployment
   docker compose up -d --build
   ```

## Testing Deployment

Run the test script to verify the deployment:
```bash
./test-deployment.sh
```

This will check:
- Service status
- Port availability
- Log file existence
- Endpoint accessibility
- Rate limiting functionality

## Troubleshooting

### Docker Compose Issues

1. Make sure you're using Docker Compose v2:
   ```bash
   docker compose version
   ```

2. If needed, you can use the full command:
   ```bash
   docker compose -f docker-compose.yml up -d
   ```

3. To check service status:
   ```bash
   docker compose ps
   ```

4. To view logs:
   ```bash
   docker compose logs
   ```

### Environment Variables

1. If you need to update environment variables:
   ```bash
   cd /home/ubuntu/apps/video-summary/backend
   ./setup-backend-env.sh
   
   cd /home/ubuntu/apps/video-summary/frontend
   ./setup-frontend-env.sh
   ```

2. After updating environment variables, restart the services:
   ```bash
   docker compose restart
   ```

### Nginx Issues

1. Check Nginx configuration:
   ```bash
   docker compose exec nginx nginx -t
   ```

2. View Nginx logs:
   ```bash
   docker compose logs nginx
   ```

3. Check Nginx access logs:
   ```bash
   docker compose exec nginx tail -f /var/log/nginx/access.log
   ```

## Backup and Recovery

1. Environment files are automatically backed up when updated:
   - `.env.backup.YYYYMMDD_HHMMSS`

2. To restore from backup:
   ```bash
   cp .env.backup.YYYYMMDD_HHMMSS .env
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
