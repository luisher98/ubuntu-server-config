# Video-To-Summary Deployment

This repository contains deployment configuration for the video-to-summary application stack.

## Components

- **Backend**: Express.js + TypeScript application ([source](https://github.com/luisher98/video-to-summary))
- **Frontend**: Web application ([source](https://github.com/luisher98/video-to-summary-app))
- **Nginx**: Reverse proxy to route traffic between services

## Server Setup

The deployment assumes the following folder structure on the server:

```
/home/ubuntu/
  ├── video-to-summary/         # Backend code (already cloned)
  ├── video-to-summary-app/     # Frontend code (already cloned)
  └── deployment/               # This repo
      ├── docker-compose.yml
      ├── backend.Dockerfile
      ├── frontend.Dockerfile
      ├── nginx.conf
      ├── frontend-nginx.conf
      ├── .env                  # Optional environment variables
      └── .github/workflows/
          ├── deploy-backend.yml
          └── deploy-frontend.yml
```

## Initial Deployment

1. Clone the backend and frontend repositories:
   ```bash
   git clone https://github.com/luisher98/video-to-summary.git /home/ubuntu/video-to-summary
   git clone https://github.com/luisher98/video-to-summary-app.git /home/ubuntu/video-to-summary-app
   ```

2. Clone this deployment repository:
   ```bash
   git clone <this-repo-url> /home/ubuntu/deployment
   ```

3. Create a `.env` file from the example (optional):
   ```bash
   cp /home/ubuntu/deployment/.env.example /home/ubuntu/deployment/.env
   # Edit with your actual configuration values
   ```

4. Copy the frontend nginx config to the frontend repo:
   ```bash
   cp /home/ubuntu/deployment/frontend-nginx.conf /home/ubuntu/video-to-summary-app/nginx.conf
   ```

5. Build and start all services:
   ```bash
   cd /home/ubuntu/deployment
   docker compose up -d
   ```

## CI/CD Setup

1. In your GitHub repository settings, add the following secrets:
   - `SERVER_IP`: Your server's IP address
   - `SSH_PRIVATE_KEY`: SSH private key for the ubuntu user

2. Push changes to the main branch to trigger automatic deployments.

## Manual Deployment

To manually deploy updates:

1. Pull the latest code for the backend/frontend:
   ```bash
   cd /home/ubuntu/video-to-summary && git pull
   cd /home/ubuntu/video-to-summary-app && git pull
   ```

2. Pull the latest deployment configuration:
   ```bash
   cd /home/ubuntu/deployment && git pull
   ```

3. Rebuild and restart services:
   ```bash
   cd /home/ubuntu/deployment
   docker compose up -d --build
   ```

## Security

- Only the Nginx container exposes an external port (80)
- All services run on an internal Docker network
- Application containers run as non-root users
- Security headers are set in Nginx configuration
