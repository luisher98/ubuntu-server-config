# Ubuntu Server Configuration

This repository contains scripts and configurations for setting up a development environment on Ubuntu 22.04 LTS or later. It includes deployment scripts for various applications and services.

## Prerequisites

- Ubuntu 22.04 LTS or later
- Git
- Docker
- A user with sudo privileges

## Quick Start Guide

1. Clean up any existing installations:
   ```bash
   rm -rf ~/apps ~/backend ~/frontend ~/ubuntu-server-config
   ```

2. Create the apps directory and clone the repository:
   ```bash
   mkdir -p ~/apps
   git clone https://github.com/luisher98/ubuntu-server-config.git ~/apps/deployment
   ```

3. Make the setup scripts executable:
   ```bash
   cd ~/apps/deployment
   chmod +x setup-vm.sh setup-env.sh setup-vpn.sh
   ```

4. Run the VM setup script:
   ```bash
   ./setup-vm.sh
   ```

5. After the script completes, log out and back in for Docker group changes to take effect.

6. Start the applications:
   ```bash
   # Copy setup-env.sh to the video-summary directory
   cd ~/apps/video-summary
   cp ~/apps/deployment/setup-env.sh .
   cp ~/apps/deployment/docker-compose.yml .
   cp ~/apps/deployment/nginx.conf nginx/
   
   # Make setup-env.sh executable and run it
   chmod +x setup-env.sh
   ./setup-env.sh
   
   # Start the services
   docker compose up -d
   ```

## Directory Structure

The setup script will create the following directory structure in your home directory:

```
~/apps/
├── deployment/          # Contains deployment scripts and configurations
│   ├── setup-vm.sh     # VM setup script
│   ├── setup-env.sh    # Environment setup script
│   ├── setup-vpn.sh    # VPN setup script
│   ├── docker-compose.yml
│   └── nginx.conf
└── video-summary/      # Main application directory
    ├── backend/        # Backend application (cloned from git)
    ├── frontend/       # Frontend application (cloned from git)
    └── nginx/          # Nginx configuration
        └── nginx.conf  # Copied from deployment directory
```

## Application Configuration

The setup script automatically configures the following applications:

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

## Troubleshooting

If you encounter any issues during setup:

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