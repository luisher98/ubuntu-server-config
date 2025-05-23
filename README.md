# Ubuntu Server Configuration

This repository contains scripts and configurations for setting up and deploying a video summary application on Ubuntu 22.04 LTS or later. It includes deployment scripts, Docker configurations, and GitHub Actions workflows for automated deployment.

## Prerequisites

- Ubuntu 22.04 LTS or later
- Git
- Docker
- A user with sudo privileges

## Enabling GitHub Actions

To enable automated deployments:

1. Fork or clone this repository to your GitHub account

2. Go to your repository's Settings > Secrets and Variables > Actions

3. Add the following secrets:
   - `SERVER_IP`: Your server's IP address
   - `SERVER_USER`: SSH username for the server
   - `SSH_PRIVATE_KEY`: Your SSH private key for server access
   - `VPN_CONFIG`: WireGuard VPN configuration (optional)

4. Enable GitHub Actions:
   - Go to your repository's Actions tab
   - Click "Enable Actions"
   - Select "Allow all actions and reusable workflows"

5. Verify workflow permissions:
   - Go to Settings > Actions > General
   - Under "Workflow permissions", select "Read and write permissions"
   - Save the changes

## Initial Setup

### Quick Setup
Run this single command to set up everything:
```bash
cd && rm -rf ~/apps ~/backend ~/frontend ~/ubuntu-server-config && mkdir -p ~/apps && git clone https://github.com/luisher98/ubuntu-server-config.git ~/apps/deployment && cd ~/apps/deployment && chmod +x setup-vm.sh && ./setup-vm.sh
```

### Detailed Setup Steps
1. Clean up any existing installations:
   ```bash
   rm -rf ~/apps ~/backend ~/frontend ~/ubuntu-server-config
   ```

2. Create the apps directory and clone the repository:
   ```bash
   mkdir -p ~/apps
   git clone https://github.com/luisher98/ubuntu-server-config.git ~/apps/deployment
   ```

3. Make the setup script executable:
   ```bash
   cd ~/apps/deployment
   chmod +x setup-vm.sh
   ```

4. Run the VM setup script:
   ```bash
   ./setup-vm.sh
   ```

5. After the script completes, log out and back in for Docker group changes to take effect.

6. Start the applications:
   ```bash
   cd ~/apps/video-summary
   docker compose up -d
   ```

## Directory Structure

The setup script creates the following directory structure:

```
~/apps/
├── deployment/          # Contains deployment scripts and configurations
│   ├── setup-vm.sh     # VM setup script
│   ├── docker-compose.yml
│   └── nginx.conf
└── video-summary/      # Main application directory
    ├── backend/        # Backend application (cloned from git)
    ├── frontend/       # Frontend application (cloned from git)
    └── nginx/          # Nginx configuration
        └── nginx.conf  # Copied from deployment directory
```

## Application Configuration

The setup script configures the following applications:

1. **Backend**
   - Repository: https://github.com/luisher98/video-to-summary-backend.git
   - Port: 5050
   - Health check endpoint: /health

2. **Frontend**
   - Repository: https://github.com/luisher98/video-to-summary-frontend.git
   - Port: 3000
   - Health check endpoint: /

3. **Nginx**
   - Image: nginx:alpine
   - Ports: 80, 443
   - Configuration: nginx.conf
   - SSL certificates: /etc/letsencrypt

## Automated Deployment

The repository includes GitHub Actions workflows for automated deployment:

1. **Server Configuration** (deploy-config.yml)
   - Triggers on changes to configuration files
   - Updates server configuration
   - Restarts all services
   - Runs health checks

2. **Backend Deployment** (deploy-backend.yml)
   - Triggers on backend-related changes
   - Updates backend code
   - Rebuilds and restarts backend service
   - Verifies backend health

3. **Frontend Deployment** (deploy-frontend.yml)
   - Triggers on frontend-related changes
   - Updates frontend code
   - Rebuilds and restarts frontend service
   - Verifies frontend health

Each workflow includes:
- Automatic backups before deployment
- Health checks after deployment
- Rollback on failure
- Detailed logging

## Troubleshooting

If you encounter issues during setup:

1. Check if all required packages are installed:
   ```bash
   sudo apt-get update
   sudo apt-get install -y git docker.io docker-compose
   ```

2. Verify Docker installation:
   ```bash
   docker --version
   docker-compose --version
   ```

3. Check directory permissions:
   ```bash
   ls -la ~/apps
   ```

4. If Docker commands fail after setup, try logging out and back in.

5. Check service logs:
   ```bash
   docker compose logs
   docker compose logs backend
   docker compose logs frontend
   docker compose logs nginx
   ```

## Handling System Updates

If you encounter package manager locks during setup:

1. Check if automatic updates are running:
   ```bash
   ps aux | grep unattended-upgrade
   ```

2. If updates are running, you can either:
   - Wait for them to complete
   - Or temporarily disable them:
     ```bash
     sudo systemctl stop unattended-upgrades
     sudo systemctl disable unattended-upgrades
     ```
   After setup is complete, you can re-enable them:
   ```bash
   sudo systemctl enable unattended-upgrades
   sudo systemctl start unattended-upgrades
   ```

## License

This project is licensed under the MIT License - see the LICENSE file for details.