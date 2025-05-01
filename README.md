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

## Prerequisites

- Ubuntu 22.04 LTS or later
- Git
- Docker and Docker Compose (will be installed by the setup script)
- User with sudo privileges

## Quick Start Guide

1. First, clean up any existing installations:
```bash
# Remove any existing installations
rm -rf ~/apps ~/backend ~/frontend ~/ubuntu-server-config
```

2. Clone the deployment repository:
```bash
# Create apps directory and clone the repository
mkdir -p ~/apps
git clone https://github.com/luisher98/ubuntu-server-config.git ~/apps/deployment
```

3. Make the setup scripts executable:
```bash
cd ~/apps/deployment
chmod +x setup-vm.sh setup-env.sh
```

4. Run the VM setup script to install Docker and create necessary directories:
```bash
./setup-vm.sh
```

5. Log out and back in for Docker group changes to take effect.

6. Run the environment setup script:
```bash
cd ~/apps/deployment
./setup-env.sh
```

7. Start the applications:
```bash
cd ~/apps/video-summary
docker compose up -d
```

or use the one-liner (recommended for fresh installations):
```bash
cd && rm -rf ~/apps ~/backend ~/frontend ~/ubuntu-server-config && mkdir -p ~/apps && git clone https://github.com/luisher98/ubuntu-server-config.git ~/apps/deployment && cd ~/apps/deployment && chmod +x ./setup-vm.sh ./setup-env.sh && ./setup-vm.sh && cd && exec bash && cd ~/apps/deployment && ./setup-env.sh && cd ~/apps/video-summary && docker compose up -d
```

## Directory Structure

The setup will create the following directory structure in your home directory:

```
~/apps/
├── deployment/           # This repository
│   ├── apps.yaml        # Application configuration
│   ├── setup-vm.sh      # Server setup script
│   ├── setup-env.sh     # Environment setup script
│   ├── docker-compose.yml
│   └── nginx.conf
└── video-summary/       # Application directory
    ├── backend/         # Backend application
    ├── frontend/        # Frontend application
    └── nginx/          # Nginx configuration
```

## Application Configuration

The `apps.yaml` file defines the structure and configuration of all applications:

```yaml
groups:
  video-summary:
    base_path: ~/apps/video-summary
    apps:
      backend:
        repo: https://github.com/luisher98/video-to-summary-backend.git
        env_file: .env
        port: 5050
        resources:
          cpus: '1'
          memory: 1G
      frontend:
        repo: https://github.com/luisher98/video-to-summary-frontend.git
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

## Environment Variables

Each application manages its own environment variables through GitHub Actions workflows in their respective repositories:

- Backend environment setup: [video-to-summary-backend](https://github.com/luisher98/video-to-summary-backend)
- Frontend environment setup: [video-to-summary-frontend](https://github.com/luisher98/video-to-summary-frontend)

## Deployment Workflows

This repository contains the following deployment workflows:

1. `deploy-config.yml`: Deploys server configuration changes
   - Updates server setup
   - Applies configuration changes
   - Restarts services

2. `deploy-backend.yml`: Deploys backend application changes
   - Updates backend code
   - Rebuilds and restarts backend container

3. `deploy-frontend.yml`: Deploys frontend application changes
   - Updates frontend code
   - Rebuilds and restarts frontend container

## Troubleshooting

If you encounter any issues:

1. Check if Docker is installed and running:
```bash
docker --version
systemctl status docker
```

2. Verify the directory structure:
```bash
ls -la ~/apps
ls -la ~/apps/video-summary
```

3. Check Docker containers:
```bash
cd ~/apps/video-summary
docker compose ps
```

4. View logs for specific services:
```bash
docker compose logs backend
docker compose logs frontend
docker compose logs nginx
```

5. If you see directories in the wrong place:
```bash
# Move backend and frontend to the correct location
mkdir -p ~/apps/video-summary
mv ~/backend ~/apps/video-summary/ 2>/dev/null || true
mv ~/frontend ~/apps/video-summary/ 2>/dev/null || true
```

## Security

- Environment variables are managed through GitHub Secrets
- Each application repository manages its own secrets
- SSL/TLS certificates are managed through certbot
- Docker containers run with limited resources
- Services are isolated in their own network

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.