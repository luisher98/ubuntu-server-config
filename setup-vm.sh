#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    git \
    curl \
    docker.io \
    python3 \
    python3-pip

# Add current user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose v2 as a plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create required directories
mkdir -p /home/ubuntu/apps/video-summary/backend
mkdir -p /home/ubuntu/apps/video-summary/frontend
mkdir -p /home/ubuntu/apps/video-summary/deployment

# Clone repositories
git clone https://github.com/luisher98/video-to-summary.git /home/ubuntu/apps/video-summary/backend
git clone https://github.com/luisher98/video-to-summary-app.git /home/ubuntu/apps/video-summary/frontend
git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/apps/video-summary/deployment

# Copy frontend nginx config
cp /home/ubuntu/apps/video-summary/deployment/frontend-nginx.conf /home/ubuntu/apps/video-summary/frontend/nginx.conf

# Create .env file from example
cp /home/ubuntu/apps/video-summary/deployment/.env.example /home/ubuntu/apps/video-summary/deployment/.env

echo "Setup complete! Please log out and log back in for docker group changes to take effect."
echo "After logging back in, you can start the deployment with:"
echo "cd /home/ubuntu/apps/video-summary/deployment && docker compose up -d" 