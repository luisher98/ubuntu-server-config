#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================
# Configuration Section
# =============================================

# Script Configuration
CONFIGURE_ENV=true  # Set to true to prompt for environment variables, false to skip
ENVIRONMENT=""      # Will be set to 'development' or 'production'

# Directory Configuration
USER_HOME=$(eval echo ~$USER)
APPS_DIR="$USER_HOME/apps"
DEPLOYMENT_DIR="$APPS_DIR/deployment"

# Application Groups Configuration
# Format: "group_name:app_name:network_name"
declare -A APP_GROUPS=(
    ["video-summary"]="video-summary:video-summary:video-summary-network"
    # Add more app groups here following the same format
)

# Application Repositories Configuration
# Format: "group_name:app_name:repo_url"
declare -A APP_REPOSITORIES=(
    ["video-summary-backend"]="video-summary:backend:https://github.com/luisher98/video-to-summary-backend.git"
    ["video-summary-frontend"]="video-summary:frontend:https://github.com/luisher98/video-to-summary-frontend.git"
    # Add more repositories here following the same format
)

# Package Installation Configuration
# Base packages required for all environments
declare -A BASE_PACKAGES=(
    ["apt-transport-https"]="true"
    ["ca-certificates"]="true"
    ["curl"]="true"
    ["gnupg"]="true"
    ["lsb-release"]="true"
    ["git"]="true"
    ["ufw"]="true"
    ["python3"]="true"
    ["python3-pip"]="true"
    ["python3-venv"]="true"
    ["python-is-python3"]="true"
    ["ffmpeg"]="true"
    ["wget"]="true"
    ["unzip"]="true"
    ["htop"]="true"
    ["net-tools"]="true"
)

# Development-specific packages
declare -A DEV_PACKAGES=(
    ["nodejs"]="true"
    ["yt-dlp"]="true"
)

# Production-specific packages
declare -A PROD_PACKAGES=(
    ["certbot"]="true"
    ["python3-certbot-nginx"]="true"
)

# Docker Configuration
DOCKER_COMPOSE_VERSION="v2.24.5"
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download"

# Node.js Configuration
NODE_VERSION="20.x"
NODE_SOURCE_URL="https://deb.nodesource.com/setup_20.x"

# Python Configuration
PYTHON_VENV_DIR="$USER_HOME/venv"
PYTHON_PACKAGES=(
    "youtube-dl"
    "yt-dlp"
)

# Environment Variables Configuration
# Default values for environment variables
declare -A ENV_DEFAULTS=(
    ["OPENAI_MODEL"]="gpt-3.5-turbo"
    ["MAX_FILE_SIZE"]="524288000"
    ["MAX_LOCAL_FILESIZE"]="209715200"
    ["MAX_LOCAL_FILESIZE_MB"]="100"
    ["RATE_LIMIT_WINDOW_MS"]="60000"
    ["RATE_LIMIT_MAX_REQUESTS"]="10"
    ["NEXT_PUBLIC_API_URL"]="http://localhost:5050"
)

# Required environment variables (must be set by user)
declare -A REQUIRED_ENV_VARS=(
    ["OPENAI_API_KEY"]="OpenAI API Key"
    ["YOUTUBE_API_KEY"]="YouTube API Key"
    ["AZURE_STORAGE_AUTH_TYPE"]="Azure Storage Authentication Type (servicePrincipal)"
    ["AZURE_STORAGE_ACCOUNT_NAME"]="Azure Storage Account Name"
    ["AZURE_STORAGE_CONNECTION_STRING"]="Azure Storage Connection String"
    ["AZURE_STORAGE_CONTAINER_NAME"]="Azure Storage Container Name"
    ["AZURE_STORAGE_ACCOUNT_KEY"]="Azure Storage Account Key"
    ["AZURE_TENANT_ID"]="Azure Tenant ID"
    ["AZURE_CLIENT_ID"]="Azure Client ID"
    ["AZURE_CLIENT_SECRET"]="Azure Client Secret"
)

# Production-specific required variables
declare -A PROD_REQUIRED_ENV_VARS=(
)

# Environment File Templates Configuration
# Backend environment file sections
declare -A BACKEND_ENV_SECTIONS=(
    ["environment"]="Environment Configuration"
    ["openai"]="OpenAI Configuration"
    ["youtube"]="YouTube Configuration"
    ["azure"]="Azure Storage Configuration"
    ["filesize"]="File Size Limits"
    ["ratelimit"]="Rate Limiting"
)

# Backend environment variables by section
declare -A BACKEND_ENV_VARS=(
    ["environment"]="NODE_ENV"
    ["openai"]="OPENAI_API_KEY OPENAI_MODEL"
    ["youtube"]="YOUTUBE_API_KEY"
    ["azure"]="AZURE_STORAGE_AUTH_TYPE AZURE_STORAGE_ACCOUNT_NAME AZURE_STORAGE_CONNECTION_STRING AZURE_STORAGE_CONTAINER_NAME AZURE_STORAGE_ACCOUNT_KEY AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET"
    ["filesize"]="MAX_FILE_SIZE MAX_LOCAL_FILESIZE MAX_LOCAL_FILESIZE_MB"
    ["ratelimit"]="RATE_LIMIT_WINDOW_MS RATE_LIMIT_MAX_REQUESTS"
)

# Frontend environment file sections
declare -A FRONTEND_ENV_SECTIONS=(
    ["api"]="API Configuration"
    ["azure"]="Azure Storage Configuration"
    ["app"]="App Configuration"
)

# Frontend environment variables by section
declare -A FRONTEND_ENV_VARS=(
    ["api"]="NEXT_PUBLIC_API_URL"
    ["azure"]="NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN"
    ["app"]="NEXT_PUBLIC_MAX_FILE_SIZE NEXT_PUBLIC_MAX_LOCAL_FILESIZE"
)

# =============================================
# End Configuration Section
# =============================================

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
🚀 Video Summary API Setup Script

Usage: $0 [OPTIONS]

Options:
    -e, --env ENV           Environment type: 'development' or 'production'
    --skip-env-config       Skip environment variable configuration
    -h, --help              Show this help message

Examples:
    $0 -e development
    $0 -e production
    $0 --skip-env-config -e development

Environments:
    development    - Backend-only setup for development and testing
    production     - Full production setup with SSL, security hardening

Prerequisites:
    - Ubuntu 20.04 LTS or newer
    - Internet connection
    - Sudo privileges
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --skip-env-config)
            CONFIGURE_ENV=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Environment selection if not provided
select_environment() {
    if [[ -z "$ENVIRONMENT" ]]; then
        echo
        print_status "🎯 Environment Selection"
        echo "Please choose your deployment environment:"
        echo
        echo "1) Development  - Backend-only setup for development and testing"
        echo "                 - HTTP only (no SSL)"
        echo "                 - Relaxed security settings"
        echo "                 - Development tools included"
        echo
        echo "2) Production   - Full production setup with SSL and security"
        echo "                 - HTTPS with Let's Encrypt SSL"
        echo "                 - Security hardening enabled"
        echo "                 - Production monitoring"
        echo
        while true; do
            read -p "Enter your choice (1 or 2): " choice
            case $choice in
                1)
                    ENVIRONMENT="development"
                    break
                    ;;
                2)
                    ENVIRONMENT="production"
                    break
                    ;;
                *)
                    print_error "Please enter 1 or 2"
                    ;;
            esac
        done
    fi

    # Validate environment
    if [[ "$ENVIRONMENT" != "development" && "$ENVIRONMENT" != "production" ]]; then
        print_error "Invalid environment: $ENVIRONMENT. Must be 'development' or 'production'"
        exit 1
    fi

    print_success "Selected environment: $ENVIRONMENT"
}

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

# Function to print section header
print_section_header() {
    echo
    echo -e "${BLUE}+--------------------------------------------------+${NC}"
    echo -e "${BLUE}|${NC} ${YELLOW}$1${NC}"
    echo -e "${BLUE}+--------------------------------------------------+${NC}"
    echo
}

# Function to print variable prompt
print_variable_prompt() {
    local var_name="$1"
    local description="$2"
    local default_value="$3"
    
    if [[ -n "$default_value" ]]; then
        echo -e "${BLUE}[?]${NC} ${YELLOW}$description${NC}"
        echo -e "${BLUE}[>]${NC} Default: ${GREEN}$default_value${NC}"
        echo -e "${BLUE}[>]${NC} Press Enter to use default or type new value:"
    else
        echo -e "${BLUE}[?]${NC} ${YELLOW}$description${NC}"
        echo -e "${BLUE}[>]${NC} Required value:"
    fi
}

# Function to prompt for environment variables
prompt_env_variables() {
    print_status "Setting up environment variables..."
    echo
    echo -e "${BLUE}Please enter the following values:${NC}"
    echo -e "${YELLOW}Required variables are marked with *${NC}"
    echo

    # Prompt for required variables
    print_section_header "Required Configuration"
    for var in "${!REQUIRED_ENV_VARS[@]}"; do
        print_variable_prompt "$var" "${REQUIRED_ENV_VARS[$var]} *"
        read -p "> " value
        if [[ -n "$value" ]]; then
            export "$var=$value"
        else
            print_warning "Warning: ${REQUIRED_ENV_VARS[$var]} is required but was not provided"
            read -p "Do you want to continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Setup aborted by user"
                exit 1
            fi
        fi
    done

    # Prompt for variables with defaults
    print_section_header "Optional Configuration"
    for var in "${!ENV_DEFAULTS[@]}"; do
        print_variable_prompt "$var" "$var" "${ENV_DEFAULTS[$var]}"
        read -p "> " value
        export "$var=${value:-${ENV_DEFAULTS[$var]}}"
    done

    # Prompt for production-specific variables
    if [[ "$ENVIRONMENT" == "production" ]]; then
        print_section_header "Production Configuration"
        for var in "${!PROD_REQUIRED_ENV_VARS[@]}"; do
            print_variable_prompt "$var" "${PROD_REQUIRED_ENV_VARS[$var]} *"
            read -p "> " value
            if [[ -n "$value" ]]; then
                export "$var=$value"
            else
                print_warning "Warning: ${PROD_REQUIRED_ENV_VARS[$var]} is required for production but was not provided"
                read -p "Do you want to continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    print_error "Setup aborted by user"
                    exit 1
                fi
            fi
        done
    fi

    # Print summary of configuration
    print_section_header "Configuration Summary"
    echo -e "${GREEN}Environment:${NC} $ENVIRONMENT"
    echo
    echo -e "${GREEN}Required Variables:${NC}"
    for var in "${!REQUIRED_ENV_VARS[@]}"; do
        if [[ -n "${!var}" ]]; then
            echo -e "  ${BLUE}[+]${NC} ${REQUIRED_ENV_VARS[$var]}: ${GREEN}Set${NC}"
        else
            echo -e "  ${RED}[-]${NC} ${REQUIRED_ENV_VARS[$var]}: ${RED}Not Set${NC}"
        fi
    done
    echo
    echo -e "${GREEN}Optional Variables:${NC}"
    for var in "${!ENV_DEFAULTS[@]}"; do
        echo -e "  ${BLUE}[*]${NC} $var: ${GREEN}${!var}${NC}"
    done

    if [[ "$ENVIRONMENT" == "production" ]]; then
        echo
        echo -e "${GREEN}Production Variables:${NC}"
        for var in "${!PROD_REQUIRED_ENV_VARS[@]}"; do
            if [[ -n "${!var}" ]]; then
                echo -e "  ${BLUE}[+]${NC} ${PROD_REQUIRED_ENV_VARS[$var]}: ${GREEN}Set${NC}"
            else
                echo -e "  ${RED}[-]${NC} ${PROD_REQUIRED_ENV_VARS[$var]}: ${RED}Not Set${NC}"
            fi
        done
    fi

    echo
    read -p "Do you want to proceed with this configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_error "Setup aborted by user"
        exit 1
    fi

    print_success "Environment variables configured successfully"
}

# Function to create environment files
create_env_files() {
    local base_path="$1"
    local env_suffix=""
    
    if [[ "$ENVIRONMENT" == "production" ]]; then
        env_suffix=".prod"
    fi
    
    # Create backend .env
    print_status "Creating backend environment file..."
    {
        # Write each section
        for section in "${!BACKEND_ENV_SECTIONS[@]}"; do
            # Skip production section if not in production environment
            if [[ "$section" == "production" && "$ENVIRONMENT" != "production" ]]; then
                continue
            fi
            
            # Write section header
            echo "# ${BACKEND_ENV_SECTIONS[$section]}"
            
            # Write variables for this section
            for var in ${BACKEND_ENV_VARS[$section]}; do
                if [[ "$var" == "NODE_ENV" ]]; then
                    echo "${var}=${ENVIRONMENT}"
                elif [[ "$var" == "DOMAIN" ]]; then
                    echo "${var}=${DOMAIN_NAME}"
                else
                    echo "${var}=${!var}"
                fi
            done
            
            # Add blank line between sections
            echo
        done
    } > "$base_path/backend/.env${env_suffix}"

    # Create frontend .env (development only)
    if [[ "$ENVIRONMENT" == "development" ]]; then
        print_status "Creating frontend environment file..."
        {
            # Write each section
            for section in "${!FRONTEND_ENV_SECTIONS[@]}"; do
                # Write section header
                echo "# ${FRONTEND_ENV_SECTIONS[$section]}"
                
                # Write variables for this section
                for var in ${FRONTEND_ENV_VARS[$section]}; do
                    echo "${var}=${!var}"
                done
                
                # Add blank line between sections
                echo
            done
        } > "$base_path/frontend/.env"
    fi

    # Set proper permissions
    chmod 600 "$base_path/backend/.env${env_suffix}" || handle_error "Failed to set permissions for backend .env file"
    if [[ "$ENVIRONMENT" == "development" ]]; then
        chmod 600 "$base_path/frontend/.env" || handle_error "Failed to set permissions for frontend .env file"
    fi

    print_success "Environment files created successfully"
}

# Install required packages
install_packages() {
    print_status "Installing required packages..."
    sudo apt-get update || handle_error "Failed to update package list"
    
    # Install base packages
    print_status "Installing base packages..."
    local base_packages=()
    for pkg in "${!BASE_PACKAGES[@]}"; do
        base_packages+=("$pkg")
    done
    sudo apt-get install -y "${base_packages[@]}" || handle_error "Failed to install base packages"
    
    # Install Node.js from NodeSource if in development
    if [[ "$ENVIRONMENT" == "development" ]]; then
        print_status "Installing Node.js..."
        curl -fsSL "$NODE_SOURCE_URL" | sudo -E bash - || handle_error "Failed to add NodeSource repository"
        sudo apt-get install -y nodejs || handle_error "Failed to install Node.js"
        
        # Install TypeScript globally using npm
        print_status "Installing TypeScript..."
        sudo npm install -g typescript || handle_error "Failed to install TypeScript"
        
        # Install development-specific packages
        print_status "Installing development packages..."
        local dev_packages=()
        for pkg in "${!DEV_PACKAGES[@]}"; do
            dev_packages+=("$pkg")
        done
        sudo apt-get install -y "${dev_packages[@]}" || handle_error "Failed to install development packages"
    fi
    
    # Install production-specific packages
    if [[ "$ENVIRONMENT" == "production" ]]; then
        print_status "Installing production packages..."
        local prod_packages=()
        for pkg in "${!PROD_PACKAGES[@]}"; do
            prod_packages+=("$pkg")
        done
        sudo apt-get install -y "${prod_packages[@]}" || handle_error "Failed to install production packages"
    fi
    
    # Create and activate Python virtual environment
    print_status "Setting up Python virtual environment..."
    python3 -m venv "$PYTHON_VENV_DIR" || handle_error "Failed to create Python virtual environment"
    source "$PYTHON_VENV_DIR/bin/activate" || handle_error "Failed to activate Python virtual environment"
    
    # Install Python packages in virtual environment
    print_status "Installing Python packages..."
    pip install --upgrade pip || handle_error "Failed to upgrade pip"
    pip install "${PYTHON_PACKAGES[@]}" || handle_error "Failed to install Python packages"
    
    # Deactivate virtual environment
    deactivate
    
    # Add virtual environment activation to .bashrc
    print_status "Adding virtual environment configuration to .bashrc..."
    echo "source $PYTHON_VENV_DIR/bin/activate" >> ~/.bashrc
    
    # Set environment variable to skip Python check for youtube-dl-exec
    print_status "Setting up environment variables..."
    echo "export YOUTUBE_DL_SKIP_PYTHON_CHECK=1" >> ~/.bashrc
    export YOUTUBE_DL_SKIP_PYTHON_CHECK=1
    
    print_success "Base packages installed successfully"
}

# Install Docker
install_docker() {
    print_status "Installing Docker..."
    
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
    sudo curl -SL "$DOCKER_COMPOSE_URL/$DOCKER_COMPOSE_VERSION/docker-compose-linux-${ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose || handle_error "Failed to download Docker Compose"
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose || handle_error "Failed to make Docker Compose executable"
    
    print_success "Docker installed successfully"
}

# Setup nginx configuration based on environment
setup_nginx_config() {
    local base_path="$1"
    local nginx_path="$base_path/nginx"
    
    print_status "Setting up nginx configuration for $ENVIRONMENT environment..."
    mkdir -p "$nginx_path" || handle_error "Failed to create nginx directory"
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        print_status "Copying development nginx configuration..."
        cp nginx/nginx.dev.conf "$nginx_path/nginx.conf" || handle_error "Failed to copy development nginx.conf"
    elif [[ "$ENVIRONMENT" == "production" ]]; then
        print_status "Copying production nginx configuration..."
        cp nginx/nginx.prod.conf "$nginx_path/nginx.conf" || handle_error "Failed to copy production nginx.conf"
        
        # Create SSL/certbot directories for production
        print_status "Setting up SSL certificate directories..."
        mkdir -p "$nginx_path/certbot/conf" || handle_error "Failed to create certbot conf directory"
        mkdir -p "$nginx_path/certbot/www" || handle_error "Failed to create certbot www directory"
        mkdir -p "$nginx_path/ssl" || handle_error "Failed to create SSL directory"
        
        # Set proper permissions
        chmod 755 "$nginx_path/certbot" || handle_error "Failed to set certbot directory permissions"
        chmod 755 "$nginx_path/certbot/conf" || handle_error "Failed to set certbot conf directory permissions"
        chmod 755 "$nginx_path/certbot/www" || handle_error "Failed to set certbot www directory permissions"
        
        print_warning "Production nginx config uses placeholder 'YOUR_DOMAIN_HERE'"
        print_warning "Run './scripts/setup-ssl.sh -d yourdomain.com -e your@email.com' to configure SSL"
    fi
    
    print_success "Nginx configuration set up for $ENVIRONMENT"
}

# Copy docker compose file based on environment
setup_docker_compose() {
    local base_path="$1"
    
    print_status "Setting up Docker Compose configuration for $ENVIRONMENT..."
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        print_status "Copying development docker-compose configuration..."
        cp docker-compose.development.yml "$base_path/docker-compose.yml" || handle_error "Failed to copy development docker-compose.yml"
    elif [[ "$ENVIRONMENT" == "production" ]]; then
        print_status "Copying production docker-compose configuration..."
        cp docker-compose.prod.yml "$base_path/docker-compose.yml" || handle_error "Failed to copy production docker-compose.yml"
    fi
    
    print_success "Docker Compose configuration set up for $ENVIRONMENT (using docker-compose.yml)"
}

# Setup application groups
setup_apps() {
    print_status "Setting up application groups..."
    
    # Create base apps directory
    mkdir -p "$APPS_DIR" || handle_error "Failed to create apps directory"
    
    # Process each app group
    for config in "${APP_GROUPS[@]}"; do
        IFS=':' read -r group app_name network <<< "$config"
        print_status "Processing group: $group"
        
        # Set base path using USER_HOME
        base_path="$APPS_DIR/$app_name"
        
        # Backup existing directory if it exists
        backup_directory "$base_path"
        
        # Create group directory
        print_status "Creating group directory: $base_path"
        mkdir -p "$base_path" || handle_error "Failed to create directory: $base_path"
        chown -R $USER:$USER "$base_path" || handle_error "Failed to set ownership: $base_path"
        
        # Process apps for this group
        for repo_config in "${APP_REPOSITORIES[@]}"; do
            IFS=':' read -r repo_group app_name repo_url <<< "$repo_config"
            
            if [ "$repo_group" = "$group" ]; then
                print_status "Processing app: $app_name"
                app_path="$base_path/$app_name"
                
                # Handle repository
                if [ ! -d "$app_path" ]; then
                    print_status "Cloning repository: $repo_url"
                    git clone "$repo_url" "$app_path" || handle_error "Failed to clone $repo_url"
                else
                    print_status "Updating existing repository: $app_name"
                    cd "$app_path" || handle_error "Failed to change directory to $app_path"
                    git fetch --all || handle_error "Failed to fetch updates for $app_name"
                    git reset --hard origin/main || handle_error "Failed to reset $app_name to main branch"
                    cd - > /dev/null
                fi
            fi
        done
        
        # Special case for video-summary group
        if [ "$group" = "video-summary" ]; then
            # Setup nginx configuration
            setup_nginx_config "$base_path"
            
            # Setup docker-compose configuration
            setup_docker_compose "$base_path"
            
            # Create environment files
            print_status "Creating environment files..."
            create_env_files "$base_path"
            
            # Create data directory for backend
            mkdir -p "$base_path/backend/data" || handle_error "Failed to create backend data directory"
            
            # Copy scripts to the deployment
            print_status "Copying deployment scripts..."
            cp -r scripts "$base_path/" || handle_error "Failed to copy scripts"
            chmod +x "$base_path/scripts/"*.sh || handle_error "Failed to make scripts executable"
            
            print_success "Application setup completed for $group"
        fi
    done
}

# Environment-specific post-setup tasks
post_setup_tasks() {
    print_status "Running post-setup tasks for $ENVIRONMENT environment..."
    
    if [[ "$ENVIRONMENT" == "production" ]]; then
        print_status "Setting up production-specific configurations..."
        
        # Create log directories
        sudo mkdir -p /var/log/video-summary /var/log/nginx
        sudo chown -R $USER:$USER /var/log/video-summary
        
        # Setup firewall (basic configuration)
        print_status "Configuring basic firewall rules..."
        sudo ufw --force reset
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw --force enable
        
        print_warning "Production environment setup completed!"
        print_warning "Next steps for production:"
        echo "1. Update backend/.env.prod with your production API keys and configuration"
        echo "2. cd $APPS_DIR/video-summary"
        echo "3. docker compose up -d"
        echo "4. Test the setup: curl http://localhost/health"
        echo ""
        echo "Optional SSL setup (if you have a domain):"
        echo "1. Point your domain DNS to this server's IP"
        echo "2. Run: ./scripts/setup-ssl.sh -d yourdomain.com -e your@email.com"
        echo "3. Run: ./scripts/deploy-production.sh -d yourdomain.com"
        
    elif [[ "$ENVIRONMENT" == "development" ]]; then
        print_status "Setting up development-specific configurations..."
        
        print_success "Development environment setup completed!"
        print_success "Next steps for development:"
        echo "1. Update backend/.env with your API keys and configuration"
        echo "2. cd $APPS_DIR/video-summary"
        echo "3. docker compose up -d"
        echo "4. Access the API at: http://localhost"
        echo "5. Check API health: curl http://localhost/health"
    fi
}

# Main execution
main() {
    echo "Video Summary API Setup Script"
    echo "=============================="
    echo
    
    # Environment selection
    select_environment
    
    print_status "Starting setup for $ENVIRONMENT environment..."
    echo
    
    # Only prompt for environment variables if CONFIGURE_ENV is true
    if [ "$CONFIGURE_ENV" = true ]; then
        prompt_env_variables
    fi
    
    install_packages
    install_docker
    setup_apps
    post_setup_tasks
    
    echo
    print_success "Setup complete for $ENVIRONMENT environment!"
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        print_warning "Please log out and back in for Docker group changes to take effect."
        print_status "After logging back in, you can start the services with:"
        echo "cd $APPS_DIR/video-summary && docker compose up -d"
    else
        print_warning "Please log out and back in for Docker group changes to take effect."
        print_status "After logging back in, complete the SSL setup and production deployment as shown above."
    fi
    
    echo
    print_status "Setup log location: This terminal output"
    print_status "Application directory: $APPS_DIR/video-summary"
}

# Run main function
main "$@" 
