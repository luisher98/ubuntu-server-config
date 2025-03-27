#!/bin/bash

# Exit on error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then 
        echo "Please do not run this script as root"
        exit 1
    fi
}

# Check if running as root
check_root

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y \
    git \
    curl \
    python3 \
    python3-pip

# Uninstall any old versions
echo "Removing old Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg || true
done

# Add Docker's official GPG key
echo "Setting up Docker repository..."
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

# Install Docker Engine and Docker Compose plugin
echo "Installing Docker Engine and Docker Compose..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create Docker CLI plugins directory
sudo mkdir -p /usr/local/lib/docker/cli-plugins

# Get system architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="aarch64"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

# Download and install Docker Compose plugin
echo "Installing Docker Compose plugin..."
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-${ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Add current user to docker group
echo "Adding user to docker group..."
sudo usermod -aG docker $USER

# Create required directories
echo "Creating application directories..."
mkdir -p /home/ubuntu/apps/video-summary/{backend,frontend,deployment}

# Clone repositories
echo "Cloning repositories..."
git clone https://github.com/luisher98/video-to-summary.git /home/ubuntu/apps/video-summary/backend || {
    echo "Error: Failed to clone backend repository"
    exit 1
}
git clone https://github.com/luisher98/video-to-summary-app.git /home/ubuntu/apps/video-summary/frontend || {
    echo "Error: Failed to clone frontend repository"
    exit 1
}
git clone https://github.com/luisher98/ubuntu-server-config.git /home/ubuntu/apps/video-summary/deployment || {
    echo "Error: Failed to clone deployment repository"
    exit 1
}

# Copy frontend nginx config
echo "Setting up Nginx configuration..."
cp /home/ubuntu/apps/video-summary/deployment/frontend-nginx.conf /home/ubuntu/apps/video-summary/frontend/nginx.conf || {
    echo "Error: Failed to copy Nginx configuration"
    exit 1
}

# Copy environment setup scripts
echo "Setting up environment configuration scripts..."
cp /home/ubuntu/apps/video-summary/deployment/setup-backend-env.sh /home/ubuntu/apps/video-summary/backend/ || {
    echo "Error: Failed to copy backend environment setup script"
    exit 1
}
cp /home/ubuntu/apps/video-summary/deployment/setup-frontend-env.sh /home/ubuntu/apps/video-summary/frontend/ || {
    echo "Error: Failed to copy frontend environment setup script"
    exit 1
}

# Make scripts executable
chmod +x /home/ubuntu/apps/video-summary/backend/setup-backend-env.sh
chmod +x /home/ubuntu/apps/video-summary/frontend/setup-frontend-env.sh

echo "✅ Setup complete! Please log out and log back in for docker group changes to take effect."
echo "After logging back in, you can:"
echo "1. Set up backend environment:"
echo "   cd /home/ubuntu/apps/video-summary/backend && ./setup-backend-env.sh"
echo "2. Set up frontend environment:"
echo "   cd /home/ubuntu/apps/video-summary/frontend && ./setup-frontend-env.sh"
echo "3. Start the deployment:"
echo "   cd /home/ubuntu/apps/video-summary/deployment && docker compose up -d" 