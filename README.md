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

2. Make the setup scripts executable:
```bash
cd /home/ubuntu/apps/deployment
chmod +x setup-vm.sh setup-env.sh
```

3. Run the VM setup script to install Docker and create necessary directories:
```bash
./setup-vm.sh
```

4. Log out and back in for Docker group changes to take effect.

5. Run the environment setup script:
```bash
cd /home/ubuntu/apps/deployment
./setup-env.sh
```

6. Start the applications:
```bash
cd /home/ubuntu/apps/video-summary
docker compose up -d
```

or use the one-liner:
```bash
cd && rm -rf /home/ubuntu/apps/* && git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/apps/deployment && cd /home/ubuntu/apps/deployment && chmod +x ./setup-vm.sh ./setup-env.sh && ./setup-vm.sh && cd && exec bash && cd /home/ubuntu/apps/deployment && ./setup-env.sh && cd /home/ubuntu/apps/video-summary && docker compose up -d
```

## Application Management

The `apps.yaml` file defines the structure and configuration of all applications:

```yaml
groups:
  video-summary:
    base_path: /home/ubuntu/apps/video-summary
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

## Directory Structure

```
/home/ubuntu/apps/
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