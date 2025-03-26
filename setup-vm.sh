#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    git \
    curl \
    docker.io \
    docker-compose \
    python3 \
    python3-pip

# Add current user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose v2
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create required directories
mkdir -p /home/ubuntu/video-to-summary
mkdir -p /home/ubuntu/video-to-summary-app
mkdir -p /home/ubuntu/deployment

# Clone repositories
git clone https://github.com/luisher98/video-to-summary.git /home/ubuntu/video-to-summary
git clone https://github.com/luisher98/video-to-summary-app.git /home/ubuntu/video-to-summary-app
git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/deployment

# Copy frontend nginx config
cp /home/ubuntu/deployment/frontend-nginx.conf /home/ubuntu/video-to-summary-app/nginx.conf

# Create .env file from example
cp /home/ubuntu/deployment/.env.example /home/ubuntu/deployment/.env

echo "Setup complete! Please log out and log back in for docker group changes to take effect."
echo "After logging back in, you can start the deployment with:"
echo "cd /home/ubuntu/deployment && docker compose up -d" 