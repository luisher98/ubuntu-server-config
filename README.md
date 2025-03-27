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
chmod +x setup-vm.sh
./setup-vm.sh

# 3. Log out and log back in for Docker group changes to take effect
exit
# Log back in to your VM

# 4. Set up environment variables
cd /home/ubuntu/apps/video-summary/deployment
chmod +x setup-env.sh
./setup-env.sh

cd /home/ubuntu/apps/video-summary/backend
chmod +x setup-backend-env.sh
./setup-backend-env.sh

cd /home/ubuntu/apps/video-summary/frontend
chmod +x setup-frontend-env.sh
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

## Environment Variables Setup

The deployment requires three separate `.env` files. Each setup script will show you the required format and validate the input. Here's how to set them up:

1. **Deployment Environment** (`/home/ubuntu/apps/video-summary/deployment/.env`):
   ```bash
   cd /home/ubuntu/apps/video-summary/deployment
   ./setup-env.sh
   ```
   Required variables:
   - NODE_ENV=production
   - PORT=5000
   - BACKEND_URL=http://localhost:5000
   - FRONTEND_URL=http://localhost:3000
   - JWT_SECRET=<generate_secure_random_string>
   - API_KEY=<generate_secure_random_string>

2. **Backend Environment** (`/home/ubuntu/apps/video-summary/backend/.env`):
   ```bash
   cd /home/ubuntu/apps/video-summary/backend
   ./setup-backend-env.sh
   ```
   Required variables:
   - PORT=5050
   - NODE_ENV=production
   - OPENAI_API_KEY=<your_openai_api_key>
   - AZURE_STORAGE_CONNECTION_STRING=<your_azure_connection_string>
   - Other variables as shown in the script

3. **Frontend Environment** (`/home/ubuntu/apps/video-summary/frontend/.env`):
   ```bash
   cd /home/ubuntu/apps/video-summary/frontend
   ./setup-frontend-env.sh
   ```
   Required variables:
   - NEXT_PUBLIC_API_URL=/api
   - NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING=<your_azure_connection_string>
   - Other variables as shown in the script

Each setup script will:
1. Check for existing `.env` file and offer to backup
2. Show you the required format
3. Let you paste all variables at once
4. Validate required variables
5. Set proper file permissions (600)

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