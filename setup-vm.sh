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
        
        # Install Go if not installed
        if ! command -v go &> /dev/null; then
            echo "Installing Go..."
            sudo apt-get update
            sudo apt-get install -y golang-go
        fi
        
        # Install yq using go install with a specific version compatible with Go 1.18
        echo "Installing yq using go install..."
        if ! go install github.com/mikefarah/yq/v3@latest; then
            echo "Error: Failed to install yq"
            exit 1
        fi
        
        # Create symlink to /usr/local/bin
        if [ ! -f "/usr/local/bin/yq" ]; then
            sudo ln -s "$HOME/go/bin/yq" /usr/local/bin/yq
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
    
    # Get the current directory
    CURRENT_DIR=$(pwd)
    echo "Current directory: $CURRENT_DIR"
    
    # Create base apps directory
    sudo mkdir -p /home/ubuntu/apps
    
    # Copy deployment files to the correct location if they don't exist
    echo "Setting up deployment files..."
    if [ "$CURRENT_DIR" != "/home/ubuntu/apps/deployment" ]; then
        for file in ./*; do
            if [ -f "$file" ] || [ -d "$file" ]; then
                filename=$(basename "$file")
                if [ ! -f "/home/ubuntu/apps/deployment/$filename" ] && [ ! -d "/home/ubuntu/apps/deployment/$filename" ]; then
                    echo "Copying $filename to deployment directory"
                    sudo cp -r "$file" "/home/ubuntu/apps/deployment/"
                fi
            fi
        done
    else
        echo "Already in deployment directory, skipping file copy"
    fi
    sudo chown -R $USER:$USER /home/ubuntu/apps/deployment
    
    # Debug: Print the contents of apps.yaml
    echo "Contents of apps.yaml:"
    cat apps.yaml
    
    # Process each group in apps.yaml
    echo "Reading groups from apps.yaml..."
    # Get only direct children of groups (first level indentation)
    groups=$(yq r apps.yaml groups | grep -v "^groups:" | grep "^  [a-zA-Z0-9_-]*:" | awk '{print $1}' | sed 's/://')
    echo "Found groups: $groups"
    
    if [ -z "$groups" ]; then
        echo "Error: No groups found in apps.yaml"
        exit 1
    fi
    
    for group in $groups; do
        echo "Processing group: $group"
        
        # Get base path for group
        base_path=$(yq r apps.yaml "groups.$group.base_path")
        echo "Base path for group $group: $base_path"
        
        if [ -z "$base_path" ]; then
            echo "Error: No base_path found for group $group"
            continue
        fi
        
        # Create group directory (excluding deployment)
        if [ "$group" != "deployment" ]; then
            echo "Creating group directory: $base_path"
            sudo mkdir -p "$base_path"
            sudo chown -R $USER:$USER "$base_path"
            
            # Process each app in the group
            echo "Reading apps for group $group..."
            # Get only direct children of apps (first level indentation)
            apps=$(yq r apps.yaml "groups.$group.apps" | grep -v "apps:" | grep "^      [a-zA-Z0-9_-]*:" | awk '{print $1}' | sed 's/://')
            echo "Found apps: $apps"
            
            if [ -z "$apps" ]; then
                echo "Warning: No apps found for group $group"
                continue
            fi
            
            for app in $apps; do
                echo "Processing app: $app"
                
                # Get app configuration
                repo=$(yq r apps.yaml "groups.$group.apps.$app.repo")
                app_path="$base_path/$app"
                echo "Repository URL: $repo"
                echo "App path: $app_path"
                
                if [ -z "$repo" ]; then
                    # Special case for nginx which doesn't have a repo field
                    if [ "$app" = "nginx" ]; then
                        echo "Skipping repository clone for nginx (image-based)"
                        # Create nginx directory
                        mkdir -p "$app_path"
                        # Maybe copy nginx config files here if needed
                        continue
                    else
                        echo "Error: No repository URL found for app $app"
                        continue
                    fi
                fi
                
                # Clone repository if it doesn't exist
                if [ ! -d "$app_path" ]; then
                    echo "Cloning repository: $repo"
                    git clone "$repo" "$app_path"
                    if [ $? -eq 0 ]; then
                        echo "Successfully cloned $repo"
                    else
                        echo "Failed to clone $repo"
                        exit 1
                    fi
                else
                    echo "Repository already exists: $app_path"
                fi
                
                # Copy setup-env.sh if it exists
                if [ -f "setup-env.sh" ]; then
                    echo "Copying setup-env.sh to $app_path"
                    cp setup-env.sh "$app_path/"
                    chmod +x "$app_path/setup-env.sh"
                fi
                
                # Create .env file if it doesn't exist
                if [ ! -f "$app_path/.env" ]; then
                    echo "Creating .env file for $app"
                    touch "$app_path/.env"
                    chmod 600 "$app_path/.env"
                fi
                
                echo "App setup complete: $app"
            done
        fi
    done
    
    echo "All applications have been set up"
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