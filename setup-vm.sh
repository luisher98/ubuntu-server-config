#!/bin/bash

# Exit on error
set -e

# Configuration
CONFIGURE_ENV=false  # Set to true to prompt for environment variables, false to skip

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

# Function to prompt for environment variables
prompt_env_variables() {
    echo "Setting up environment variables..."
    echo "Please enter the following values (press Enter to skip if not needed):"
    
    # Backend variables
    read -p "OpenAI API Key: " OPENAI_API_KEY
    read -p "OpenAI Model (default: gpt-3.5-turbo): " OPENAI_MODEL
    OPENAI_MODEL=${OPENAI_MODEL:-gpt-3.5-turbo}
    
    read -p "YouTube API Key: " YOUTUBE_API_KEY
    
    echo "Azure Storage Configuration:"
    read -p "Azure Storage Auth Type (default: servicePrincipal): " AZURE_STORAGE_AUTH_TYPE
    AZURE_STORAGE_AUTH_TYPE=${AZURE_STORAGE_AUTH_TYPE:-servicePrincipal}
    read -p "Azure Storage Account Name: " AZURE_STORAGE_ACCOUNT_NAME
    read -p "Azure Storage Connection String: " AZURE_STORAGE_CONNECTION_STRING
    read -p "Azure Storage Container Name: " AZURE_STORAGE_CONTAINER_NAME
    read -p "Azure Storage Account Key: " AZURE_STORAGE_ACCOUNT_KEY
    read -p "Azure Tenant ID: " AZURE_TENANT_ID
    read -p "Azure Client ID: " AZURE_CLIENT_ID
    read -p "Azure Client Secret: " AZURE_CLIENT_SECRET
    
    echo "File Size Limits:"
    read -p "Max File Size in bytes (default: 524288000): " MAX_FILE_SIZE
    MAX_FILE_SIZE=${MAX_FILE_SIZE:-524288000}
    read -p "Max Local File Size in bytes (default: 209715200): " MAX_LOCAL_FILESIZE
    MAX_LOCAL_FILESIZE=${MAX_LOCAL_FILESIZE:-209715200}
    read -p "Max Local File Size in MB (default: 100): " MAX_LOCAL_FILESIZE_MB
    MAX_LOCAL_FILESIZE_MB=${MAX_LOCAL_FILESIZE_MB:-100}
    
    echo "Rate Limiting:"
    read -p "Rate Limit Window in ms (default: 60000): " RATE_LIMIT_WINDOW_MS
    RATE_LIMIT_WINDOW_MS=${RATE_LIMIT_WINDOW_MS:-60000}
    read -p "Rate Limit Max Requests (default: 10): " RATE_LIMIT_MAX_REQUESTS
    RATE_LIMIT_MAX_REQUESTS=${RATE_LIMIT_MAX_REQUESTS:-10}
    
    # Frontend variables
    read -p "Next.js Public API URL (default: http://localhost:5050): " NEXT_PUBLIC_API_URL
    NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-http://localhost:5050}
    
    echo "Frontend Azure Storage Configuration:"
    read -p "Next.js Public Azure Storage Account Name: " NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME
    read -p "Next.js Public Azure Storage Container Name: " NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME
    read -p "Next.js Public Azure Storage SAS Token: " NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN
    
    echo "Frontend App Configuration:"
    read -p "Next.js Public Max File Size in bytes (default: 524288000): " NEXT_PUBLIC_MAX_FILE_SIZE
    NEXT_PUBLIC_MAX_FILE_SIZE=${NEXT_PUBLIC_MAX_FILE_SIZE:-524288000}
    read -p "Next.js Public Max Local File Size in bytes (default: 209715200): " NEXT_PUBLIC_MAX_LOCAL_FILESIZE
    NEXT_PUBLIC_MAX_LOCAL_FILESIZE=${NEXT_PUBLIC_MAX_LOCAL_FILESIZE:-209715200}
    
    # Export variables for use in the script
    export OPENAI_API_KEY OPENAI_MODEL YOUTUBE_API_KEY
    export AZURE_STORAGE_AUTH_TYPE AZURE_STORAGE_ACCOUNT_NAME AZURE_STORAGE_CONNECTION_STRING
    export AZURE_STORAGE_CONTAINER_NAME AZURE_STORAGE_ACCOUNT_KEY AZURE_TENANT_ID
    export AZURE_CLIENT_ID AZURE_CLIENT_SECRET
    export MAX_FILE_SIZE MAX_LOCAL_FILESIZE MAX_LOCAL_FILESIZE_MB
    export RATE_LIMIT_WINDOW_MS RATE_LIMIT_MAX_REQUESTS
    export NEXT_PUBLIC_API_URL NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME
    export NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN
    export NEXT_PUBLIC_MAX_FILE_SIZE NEXT_PUBLIC_MAX_LOCAL_FILESIZE
}

# Function to create environment files
create_env_files() {
    local base_path="$1"
    
    # Create backend .env
    cat > "$base_path/backend/.env" << EOL
# OpenAI Configuration
OPENAI_API_KEY=${OPENAI_API_KEY}
OPENAI_MODEL=${OPENAI_MODEL}

# YouTube Configuration
YOUTUBE_API_KEY=${YOUTUBE_API_KEY}

# Azure Storage Configuration
AZURE_STORAGE_AUTH_TYPE=${AZURE_STORAGE_AUTH_TYPE}
AZURE_STORAGE_ACCOUNT_NAME=${AZURE_STORAGE_ACCOUNT_NAME}
AZURE_STORAGE_CONNECTION_STRING=${AZURE_STORAGE_CONNECTION_STRING}
AZURE_STORAGE_CONTAINER_NAME=${AZURE_STORAGE_CONTAINER_NAME}
AZURE_STORAGE_ACCOUNT_KEY=${AZURE_STORAGE_ACCOUNT_KEY}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}

# File Size Limits
MAX_FILE_SIZE=${MAX_FILE_SIZE}
MAX_LOCAL_FILESIZE=${MAX_LOCAL_FILESIZE}
MAX_LOCAL_FILESIZE_MB=${MAX_LOCAL_FILESIZE_MB}

# Rate Limiting
RATE_LIMIT_WINDOW_MS=${RATE_LIMIT_WINDOW_MS}
RATE_LIMIT_MAX_REQUESTS=${RATE_LIMIT_MAX_REQUESTS}
EOL

    # Create frontend .env
    cat > "$base_path/frontend/.env" << EOL
NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

# Azure Storage Configuration
NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME=${NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME}
NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME=${NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME}
NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN=${NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN}

# App Configuration
NEXT_PUBLIC_MAX_FILE_SIZE=${NEXT_PUBLIC_MAX_FILE_SIZE}
NEXT_PUBLIC_MAX_LOCAL_FILESIZE=${NEXT_PUBLIC_MAX_LOCAL_FILESIZE}
EOL
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
        ufw \
        nodejs \
        npm \
        python3 \
        python3-pip \
        python-is-python3 || handle_error "Failed to install required packages"
    
    # Install TypeScript globally
    echo "Installing TypeScript..."
    sudo npm install -g typescript || handle_error "Failed to install TypeScript"
    
    # Install Python packages
    echo "Installing Python packages..."
    sudo pip3 install --upgrade pip || handle_error "Failed to upgrade pip"
    sudo pip3 install youtube-dl || handle_error "Failed to install youtube-dl"
    
    # Set environment variable to skip Python check for youtube-dl-exec
    echo "Setting up environment variables..."
    echo "export YOUTUBE_DL_SKIP_PYTHON_CHECK=1" >> ~/.bashrc
    export YOUTUBE_DL_SKIP_PYTHON_CHECK=1
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
            
            # Create environment files
            echo "Creating environment files..."
            create_env_files "$base_path"
            
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

# Only prompt for environment variables if CONFIGURE_ENV is true
if [ "$CONFIGURE_ENV" = true ]; then
    prompt_env_variables
fi

install_packages
install_docker
setup_apps

echo "✅ Setup complete! Please log out and back in for Docker group changes to take effect."
echo "After logging back in, you can use the following commands:"
echo "1. cd $APPS_DIR/video-summary"
echo "2. docker compose up -d" 
