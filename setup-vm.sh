#!/bin/bash

# Exit on error
set -e

# Log file
LOG_FILE="$HOME/vm-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "Error occurred in line $line_number with exit code $exit_code"
    exit $exit_code
}
trap 'handle_error ${LINENO}' ERR

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    log "Please do not run as root"
    exit 1
fi

# Backup function
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup_file="${file}.$(date +%Y%m%d_%H%M%S).bak"
        log "Creating backup of $file to $backup_file"
        cp "$file" "$backup_file"
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f /tmp/docker-archive-keyring.gpg
    rm -f /tmp/docker.list
}

# Check if yq is installed
check_yq() {
    if ! command -v yq &> /dev/null; then
        log "Installing yq..."
        
        # Install Go if not installed
        if ! command -v go &> /dev/null; then
            log "Installing Go..."
            sudo apt-get update
            sudo apt-get install -y golang-go
        fi
        
        # Check Go version
        go_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [ "$(echo "$go_version < 1.18" | bc)" -eq 1 ]; then
            log "Error: Go version must be 1.18 or higher"
            exit 1
        fi
        
        # Install yq using go install with a specific version compatible with Go 1.18
        log "Installing yq using go install..."
        if ! go install github.com/mikefarah/yq/v3@latest; then
            log "Error: Failed to install yq"
            exit 1
        fi
        
        # Create symlink to /usr/local/bin
        if [ ! -f "/usr/local/bin/yq" ]; then
            sudo ln -s "$HOME/go/bin/yq" /usr/local/bin/yq
        fi
        
        # Verify installation
        if ! yq --version &> /dev/null; then
            log "Error: Failed to verify yq installation"
            exit 1
        fi
        
        log "yq installed successfully"
    else
        log "yq is already installed"
    fi
}

# Validate config file
validate_config() {
    if [ ! -f "apps.yaml" ]; then
        log "Error: apps.yaml not found"
        exit 1
    fi
    
    # Backup config file
    backup_file "apps.yaml"
    
    # Validate YAML syntax using Python
    if ! python3 -c "import yaml; yaml.safe_load(open('apps.yaml'))" > /dev/null 2>&1; then
        log "Error: Invalid YAML syntax in apps.yaml"
        exit 1
    fi
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git \
        bc \
        nano
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
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
        log "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Download Docker Compose
    log "Downloading Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-$ARCH" -o /usr/local/lib/docker/cli-plugins/docker-compose
    
    # Make Docker Compose executable
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
    # Verify Docker installation
    if ! docker --version &> /dev/null; then
        log "Error: Failed to verify Docker installation"
        exit 1
    fi
    
    # Verify Docker Compose installation
    if ! docker compose version &> /dev/null; then
        log "Error: Failed to verify Docker Compose installation"
        exit 1
    fi
    
    log "Docker and Docker Compose installed successfully"
}

# Parse YAML using Python
parse_yaml_with_python() {
    python3 -c "
import yaml
import sys
import json
try:
    data = yaml.safe_load(open('$1'))
    if '$2' == 'groups':
        if 'groups' in data:
            print(' '.join(data['groups'].keys()))
    elif '$2' == 'apps':
        group = '$3'
        if 'groups' in data and group in data['groups'] and 'apps' in data['groups'][group]:
            print(' '.join(data['groups'][group]['apps'].keys()))
    elif '$2' == 'repo':
        group = '$3'
        app = '$4'
        if 'groups' in data and group in data['groups'] and 'apps' in data['groups'][group] and app in data['groups'][group]['apps']:
            repo = data['groups'][group]['apps'][app].get('repo', '')
            print(repo)
    elif '$2' == 'base_path':
        group = '$3'
        if 'groups' in data and group in data['groups']:
            print(data['groups'][group].get('base_path', ''))
except Exception as e:
    print('Error parsing YAML: ' + str(e), file=sys.stderr)
    sys.exit(1)
"
}

# Setup applications
setup_apps() {
    log "Setting up application groups..."
    
    # Get the current directory
    CURRENT_DIR=$(pwd)
    log "Current directory: $CURRENT_DIR"
    
    # Create base apps directory
    sudo mkdir -p /home/ubuntu/apps
    
    # Copy deployment files to the correct location if they don't exist
    log "Setting up deployment files..."
    if [ "$CURRENT_DIR" != "/home/ubuntu/apps/deployment" ]; then
        for file in ./*; do
            if [ -f "$file" ] || [ -d "$file" ]; then
                filename=$(basename "$file")
                if [ ! -f "/home/ubuntu/apps/deployment/$filename" ] && [ ! -d "/home/ubuntu/apps/deployment/$filename" ]; then
                    log "Copying $filename to deployment directory"
                    sudo cp -r "$file" "/home/ubuntu/apps/deployment/"
                fi
            fi
        done
    else
        log "Already in deployment directory, skipping file copy"
    fi
    sudo chown -R $USER:$USER /home/ubuntu/apps/deployment
    
    # Debug: Print the contents of apps.yaml
    log "Contents of apps.yaml:"
    cat apps.yaml
    
    # Make sure PyYAML is installed
    log "Checking for PyYAML..."
    if ! python3 -c "import yaml" &> /dev/null; then
        log "Installing PyYAML..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
        sudo pip3 install pyyaml
    fi
    
    # Parse the YAML file using Python
    log "Parsing YAML file with Python..."
    groups=$(parse_yaml_with_python apps.yaml groups)
    log "Found groups: $groups"
    
    if [ -z "$groups" ]; then
        log "Error: No groups found in apps.yaml"
        exit 1
    fi
    
    for group in $groups; do
        log "Processing group: $group"
        
        # Get base path for group
        base_path=$(parse_yaml_with_python apps.yaml base_path "$group")
        log "Base path for group $group: $base_path"
        
        if [ -z "$base_path" ]; then
            log "Error: No base_path found for group $group"
            continue
        fi
        
        # Create group directory (excluding deployment)
        if [ "$group" != "deployment" ]; then
            log "Creating group directory: $base_path"
            sudo mkdir -p "$base_path"
            sudo chown -R $USER:$USER "$base_path"
            
            # Get apps for this group
            log "Reading apps for group $group..."
            apps=$(parse_yaml_with_python apps.yaml apps "$group")
            log "Found apps: $apps"
            
            if [ -z "$apps" ]; then
                log "Warning: No apps found for group $group"
                continue
            fi
            
            for app in $apps; do
                log "Processing app: $app"
                
                # Get app configuration
                repo=$(parse_yaml_with_python apps.yaml repo "$group" "$app")
                app_path="$base_path/$app"
                log "Repository URL: $repo"
                log "App path: $app_path"
                
                if [ -z "$repo" ]; then
                    # Special case for nginx which doesn't have a repo field
                    if [ "$app" = "nginx" ]; then
                        log "Skipping repository clone for nginx (image-based)"
                        # Create nginx directory
                        mkdir -p "$app_path"
                        # Copy nginx config files if needed
                        if [ -f "nginx.conf" ]; then
                            log "Copying nginx.conf to $app_path"
                            cp nginx.conf "$app_path/"
                        fi
                        continue
                    else
                        log "Error: No repository URL found for app $app"
                        continue
                    fi
                fi
                
                # Clone repository if it doesn't exist
                if [ ! -d "$app_path" ]; then
                    log "Cloning repository: $repo"
                    git clone "$repo" "$app_path"
                    if [ $? -eq 0 ]; then
                        log "Successfully cloned $repo"
                    else
                        log "Failed to clone $repo"
                        exit 1
                    fi
                else
                    log "Repository already exists: $app_path"
                fi
                
                # Create .env file if it doesn't exist
                if [ ! -f "$app_path/.env" ]; then
                    log "Creating .env file for $app"
                    touch "$app_path/.env"
                    chmod 600 "$app_path/.env"
                fi
                
                log "App setup complete: $app"
            done
            
            # Copy docker-compose.yml to the group directory
            if [ -f "docker-compose.yml" ]; then
                log "Copying docker-compose.yml to $base_path"
                cp docker-compose.yml "$base_path/"
            fi
        fi
    done
    
    log "All applications have been set up"
}

# Main setup function
setup_vm() {
    log "Starting VM setup..."
    
    # Check dependencies
    check_yq
    
    # Validate config
    validate_config
    
    # Install packages
    install_packages
    
    # Install Docker
    install_docker
    
    # Setup applications
    setup_apps
    
    log "✅ Setup complete! Please log out and back in for Docker group changes to take effect."
    log "After logging back in, you can use the following commands:"
    log "1. cd /home/ubuntu/apps/video-summary"
    log "2. docker compose up -d"
}

# Run setup
setup_vm

# Cleanup
cleanup 