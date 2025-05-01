#!/bin/bash

# Exit on error
set -e

# Configuration
APPS_CONFIG=(
    "video-summary:/home/uoc/apps/video-summary:video-summary-network"
)

APP_REPOS=(
    "video-summary:backend:https://github.com/luisher98/video-to-summary-backend.git"
    "video-summary:frontend:https://github.com/luisher98/video-to-summary-frontend.git"
)

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run as root"
    exit 1
fi

# Get the current user's home directory
USER_HOME=$(eval echo ~$USER)
APPS_DIR="$USER_HOME/apps"
DEPLOYMENT_DIR="$APPS_DIR/deployment"

# Check if yq is installed
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Installing yq..."
        
        # Check if Go is installed
        if ! command -v go &> /dev/null; then
            echo "Installing Go..."
            sudo apt-get update
            sudo apt-get install -y golang-go
            if [ $? -ne 0 ]; then
                echo "Error: Failed to install Go"
                exit 1
            fi
        else
            echo "Go is already installed"
        fi
        
        # Install yq using go install with a specific version compatible with Go 1.18
        echo "Installing yq using go install..."
        if ! go install github.com/mikefarah/yq/v3@latest; then
            echo "Error: Failed to install yq"
            exit 1
        fi
        
        # Create symlink to /usr/local/bin if it doesn't exist
        if [ ! -f "/usr/local/bin/yq" ]; then
            sudo ln -s "$HOME/go/bin/yq" /usr/local/bin/yq
            if [ $? -ne 0 ]; then
                echo "Error: Failed to create yq symlink"
                exit 1
            fi
        fi
        
        # Verify installation
        if ! yq --version &> /dev/null; then
            echo "Error: Failed to verify yq installation"
            exit 1
        fi
        
        echo "yq installed successfully"
    else
        echo "yq is already installed"
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
        git \
        ufw
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
    mkdir -p "$APPS_DIR"
    
    # Process each app group
    for config in "${APPS_CONFIG[@]}"; do
        IFS=':' read -r group base_path network <<< "$config"
        echo "Processing group: $group"
        
        # Create group directory
        echo "Creating group directory: $base_path"
        mkdir -p "$base_path"
        chown -R $USER:$USER "$base_path"
        
        # Process apps for this group
        for repo_config in "${APP_REPOS[@]}"; do
            IFS=':' read -r repo_group app_name repo_url <<< "$repo_config"
            
            if [ "$repo_group" = "$group" ]; then
                echo "Processing app: $app_name"
                app_path="$base_path/$app_name"
                
                # Handle repository
                if [ ! -d "$app_path" ]; then
                    echo "Cloning repository: $repo_url"
                    git clone "$repo_url" "$app_path"
                    if [ $? -ne 0 ]; then
                        echo "Failed to clone $repo_url"
                        exit 1
                    fi
                else
                    echo "Updating existing repository: $app_name"
                    cd "$app_path"
                    git fetch --all
                    git reset --hard origin/main
                    if [ $? -ne 0 ]; then
                        echo "Failed to update $app_name"
                        exit 1
                    fi
                    cd - > /dev/null
                fi
            fi
        done
        
        # Special case for nginx
        if [ "$group" = "video-summary" ]; then
            nginx_path="$base_path/nginx"
            mkdir -p "$nginx_path"
            if [ -f "nginx.conf" ]; then
                echo "Copying nginx.conf to $nginx_path"
                cp nginx.conf "$nginx_path/"
            fi
        fi
    done
}

# Main execution
echo "Starting VM setup..."
check_yq
install_packages
install_docker
setup_apps

echo "✅ Setup complete! Please log out and back in for Docker group changes to take effect."
echo "After logging back in, you can use the following commands:"
echo "1. cd $APPS_DIR/video-summary"
echo "2. ./setup-env.sh"
echo "3. docker compose up -d" 
echo "3. docker compose up -d" 
