#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    git \
    curl \
    python3 \
    python3-pip

# Uninstall any old versions
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg
done

# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Docker Compose
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

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