#!/bin/bash

# Exit on error
set -e

# Configuration
APPS_CONFIG=(
    "video-summary:video-summary:video-summary-network"
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

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        handle_error "$1 is not installed"
    fi
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        handle_error "$1 does not exist"
    fi
}

# Function to backup existing directory
backup_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        local backup_dir="${dir}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Backing up existing directory to $backup_dir"
        mv "$dir" "$backup_dir" || handle_error "Failed to backup $dir"
    fi
}

# Install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt-get update || handle_error "Failed to update package list"
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git \
        ufw || handle_error "Failed to install required packages"
}

# Install Docker
install_docker() {
    echo "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || handle_error "Failed to add Docker GPG key"
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || handle_error "Failed to set up Docker repository"
    
    # Install Docker Engine
    sudo apt-get update || handle_error "Failed to update package list"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io || handle_error "Failed to install Docker"
    
    # Add user to docker group
    sudo usermod -aG docker $USER || handle_error "Failed to add user to docker group"
    
    # Create Docker CLI plugins directory
    sudo mkdir -p /usr/local/lib/docker/cli-plugins || handle_error "Failed to create Docker CLI plugins directory"
    
    # Get system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="aarch64"
    else
        handle_error "Unsupported architecture: $ARCH"
    fi
    
    # Download and install Docker Compose plugin
    sudo curl -SL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-${ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose || handle_error "Failed to download Docker Compose"
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose || handle_error "Failed to make Docker Compose executable"
}

# Setup application groups
setup_apps() {
    echo "Setting up application groups..."
    
    # Check required files
    check_file "docker-compose.yml"
    check_file "nginx.conf"
    
    # Create base apps directory
    mkdir -p "$APPS_DIR" || handle_error "Failed to create apps directory"
    
    # Process each app group
    for config in "${APPS_CONFIG[@]}"; do
        IFS=':' read -r group app_name network <<< "$config"
        echo "Processing group: $group"
        
        # Set base path using USER_HOME
        base_path="$APPS_DIR/$app_name"
        
        # Backup existing directory if it exists
        backup_directory "$base_path"
        
        # Create group directory
        echo "Creating group directory: $base_path"
        mkdir -p "$base_path" || handle_error "Failed to create directory: $base_path"
        chown -R $USER:$USER "$base_path" || handle_error "Failed to set ownership: $base_path"
        
        # Process apps for this group
        for repo_config in "${APP_REPOS[@]}"; do
            IFS=':' read -r repo_group app_name repo_url <<< "$repo_config"
            
            if [ "$repo_group" = "$group" ]; then
                echo "Processing app: $app_name"
                app_path="$base_path/$app_name"
                
                # Handle repository
                if [ ! -d "$app_path" ]; then
                    echo "Cloning repository: $repo_url"
                    git clone "$repo_url" "$app_path" || handle_error "Failed to clone $repo_url"
                else
                    echo "Updating existing repository: $app_name"
                    cd "$app_path" || handle_error "Failed to change directory to $app_path"
                    git fetch --all || handle_error "Failed to fetch updates for $app_name"
                    git reset --hard origin/main || handle_error "Failed to reset $app_name to main branch"
                    cd - > /dev/null
                fi
            fi
        done
        
        # Special case for nginx
        if [ "$group" = "video-summary" ]; then
            nginx_path="$base_path/nginx"
            mkdir -p "$nginx_path" || handle_error "Failed to create nginx directory"
            
            echo "Copying nginx.conf to $nginx_path"
            cp nginx.conf "$nginx_path/" || handle_error "Failed to copy nginx.conf"
            
            echo "Copying docker-compose.yml to $base_path"
            cp docker-compose.yml "$base_path/" || handle_error "Failed to copy docker-compose.yml"
            
            # Create .env files
            echo "Creating environment files..."
            cat > "$base_path/backend/.env" << 'EOL'
NODE_ENV=production
PORT=5050
EOL
            
            cat > "$base_path/frontend/.env" << 'EOL'
NODE_ENV=production
PORT=3000
EOL
            
            # Create certbot directories
            mkdir -p "$nginx_path/certbot/conf" || handle_error "Failed to create certbot conf directory"
            mkdir -p "$nginx_path/certbot/www" || handle_error "Failed to create certbot www directory"
            chmod 755 "$nginx_path/certbot" || handle_error "Failed to set certbot directory permissions"
            chmod 755 "$nginx_path/certbot/conf" || handle_error "Failed to set certbot conf directory permissions"
            chmod 755 "$nginx_path/certbot/www" || handle_error "Failed to set certbot www directory permissions"
        fi
    done
}

# Main execution
echo "Starting VM setup..."
install_packages
install_docker
setup_apps

echo "✅ Setup complete! Please log out and back in for Docker group changes to take effect."
echo "After logging back in, you can use the following commands:"
echo "1. cd $APPS_DIR/video-summary"
echo "2. docker compose up -d" 
