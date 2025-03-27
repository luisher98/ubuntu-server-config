#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run as root"
    exit 1
fi

# Check if yq is installed
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Installing yq..."
        
        # Get system architecture
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            ARCH="amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            ARCH="arm64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        
        # Download and install yq
        sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}"
        sudo chmod a+x /usr/local/bin/yq
    fi
}

# Validate config file
validate_config() {
    if [ ! -f "apps.yaml" ]; then
        echo "Error: apps.yaml not found"
        exit 1
    fi
}

# Install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git
}

# Install Docker
install_docker() {
    echo "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Create Docker CLI plugins directory
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    
    # Get system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="aarch64"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Download and install Docker Compose plugin
    sudo curl -SL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-${ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
}

# Setup application groups
setup_apps() {
    echo "Setting up application groups..."
    
    # Create base apps directory
    sudo mkdir -p /home/ubuntu/apps
    
    # Process each group in apps.yaml
    yq e '.groups | keys | .[]' apps.yaml | while read -r group; do
        echo "Setting up group: $group"
        
        # Get base path for group
        base_path=$(yq e ".groups.$group.base_path" apps.yaml)
        
        # Create group directory
        sudo mkdir -p "$base_path"
        sudo chown -R $USER:$USER "$base_path"
        
        # Process each app in the group
        yq e ".groups.$group.apps | keys | .[]" apps.yaml | while read -r app; do
            echo "Setting up app: $app"
            
            # Get app configuration
            repo=$(yq e ".groups.$group.apps.$app.repo" apps.yaml)
            app_path="$base_path/$app"
            
            # Clone repository if it doesn't exist
            if [ ! -d "$app_path" ]; then
                git clone "$repo" "$app_path"
            fi
            
            # Copy setup-env.sh if it exists
            if [ -f "setup-env.sh" ]; then
                cp setup-env.sh "$app_path/"
                chmod +x "$app_path/setup-env.sh"
            fi
        done
    done
}

# Main script
echo "Starting VM setup..."

check_yq
validate_config
install_packages
install_docker
setup_apps

echo "✅ Setup complete! Please log out and back in for Docker group changes to take effect."
echo "After logging back in, you can use the following commands:"
echo "1. cd /home/ubuntu/apps/video-summary"
echo "2. ./setup-env.sh"
echo "3. docker compose up -d" 