# Ubuntu Server Configuration

This repository contains the configuration and deployment scripts for managing applications on an Ubuntu server.

## Features

- Configuration-based application management using `apps.yaml`
- Automated deployment workflows for:
  - Server configuration changes
  - Frontend application updates
  - Backend application updates
- Docker-based containerization
- Nginx reverse proxy with SSL/TLS support
- Resource limits and monitoring
- Health checks for all services

## Quick Start Guide

1. Clone the deployment repository:
```bash
git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/apps/deployment
```

2. Run the VM setup script to install Docker and create necessary directories:
```bash
cd /home/ubuntu/apps/deployment
./setup-vm.sh
```

3. Log out and back in for Docker group changes to take effect.

4. Set up environment variables for each application:
```bash
# Set up backend environment
cd /home/ubuntu/apps/video-summary/backend
./setup-env.sh

# Set up frontend environment
cd /home/ubuntu/apps/video-summary/frontend
./setup-env.sh
```

5. Start the applications:
```bash
cd /home/ubuntu/apps/deployment
docker compose up -d
```

or 
```bash
cd && rm -rf /home/ubuntu/apps/* && git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/apps/deployment && cd /home/ubuntu/apps/deployment && chmod +x ./setup-vm.sh && ./setup-vm.sh && cd && exec bash && cd /home/ubuntu/apps/ && ls
```

## Application Management

The `apps.yaml` file defines the structure and configuration of all applications:

```yaml
groups:
  video-summary:
    base_path: /home/ubuntu/apps/video-summary
    apps:
      backend:
        repo: https://github.com/luisher98/video-summary-backend.git
        env_file: .env
        port: 5050
        resources:
          cpus: '1'
          memory: 1G
      frontend:
        repo: https://github.com/luisher98/video-summary-frontend.git
        env_file: .env
        port: 3000
        resources:
          cpus: '0.5'
          memory: 512M
      nginx:
        image: nginx:alpine
        ports:
          - "80:80"
          - "443:443"
        resources:
          cpus: '0.5'
          memory: 256M
        volumes:
          - ./nginx.conf:/etc/nginx/nginx.conf:ro
          - ./certbot/conf:/etc/letsencrypt
          - ./certbot/www:/var/www/certbot
```

Use the `manage-apps.sh` script to manage applications:

```bash
# List all applications
./manage-apps.sh list

# Add a new application group
./manage-apps.sh add-group my-app /home/ubuntu/apps/my-app

# Add a new application to a group
./manage-apps.sh add-app my-app service https://github.com/example/service.git

# Remove an application group
./manage-apps.sh remove-group my-app

# Remove an application from a group
./manage-apps.sh remove-app my-app service
```

## Directory Structure

```
/home/ubuntu/apps/
├── deployment/           # Deployment configuration and scripts
│   ├── apps.yaml        # Application configuration
│   ├── setup-vm.sh      # VM setup script
│   ├── manage-apps.sh   # Application management script
│   ├── docker-compose.yml
│   └── nginx.conf
└── video-summary/       # Video summary application
    ├── backend/         # Backend service
    │   └── .env        # Backend environment variables
    └── frontend/        # Frontend service
        └── .env        # Frontend environment variables
```

## Environment Variables

Each application has its own `.env` file for configuration:

### Backend (.env)
```env
# Server Configuration
PORT=5050
NODE_ENV=production
WEBSITE_HOSTNAME=

# OpenAI Configuration
OPENAI_API_KEY=your_key_here
OPENAI_MODEL=gpt-3.5-turbo

# YouTube Configuration
YOUTUBE_API_KEY=your_key_here

# Azure Storage Configuration
AZURE_STORAGE_ACCOUNT_NAME=summarystorage
AZURE_STORAGE_CONNECTION_STRING=your_connection_string
AZURE_STORAGE_CONTAINER_NAME=summary
AZURE_TENANT_ID=your_tenant_id
AZURE_CLIENT_ID=your_client_id
AZURE_CLIENT_SECRET=your_client_secret

# File Size Limits
MAX_FILE_SIZE=524288000  # 500MB
MAX_LOCAL_FILESIZE=209715200  # 200MB
MAX_LOCAL_FILESIZE_MB=100

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000  # 1 minute
RATE_LIMIT_MAX_REQUESTS=10  # 10 requests per minute

# Temporary Directories
TEMP_DIR=
TEMP_VIDEOS_DIR=
TEMP_AUDIOS_DIR=
TEMP_SESSIONS_DIR=
```

### Frontend (.env)
```env
# API Configuration
NEXT_PUBLIC_API_URL=/api

# Azure Storage Configuration
NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME=summarystorage
NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME=summary
NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING=your_connection_string

# Optional YouTube Configuration
NEXT_PUBLIC_YOUTUBE_API_KEY=your_key_here
```

## Security

- Environment variables are stored in `.env` files (not committed to Git)
- SSL/TLS certificates are managed by Certbot
- Rate limiting is configured in Nginx
- Resource limits are set for all containers
- Health checks monitor service status

## Monitoring

- Container health checks
- Nginx access and error logs
- Docker container logs
- Resource usage monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.