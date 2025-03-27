#!/bin/bash

# Exit on error
set -e

# Function to generate a secure random string
generate_secret() {
    openssl rand -base64 32
}

# Function to validate API key format
validate_api_key() {
    local key="$1"
    if [[ ! "$key" =~ ^[A-Za-z0-9_-]{32,}$ ]]; then
        echo "Error: Invalid API key format"
        return 1
    fi
    return 0
}

# Function to validate connection string format
validate_connection_string() {
    local conn="$1"
    if [[ ! "$conn" =~ ^DefaultEndpointsProtocol=https;AccountName=.*;AccountKey=.*;EndpointSuffix=core\.windows\.net$ ]]; then
        echo "Error: Invalid Azure Storage connection string format"
        return 1
    fi
    return 0
}

# Function to prompt for sensitive input
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    local validate_func="$3"
    local value
    while true; do
        echo -n "$prompt: "
        read -s value
        echo
        if [ -n "$validate_func" ]; then
            if $validate_func "$value"; then
                break
            fi
        else
            break
        fi
    done
    echo "$var_name=$value" >> .env
}

# Function to validate required variables
validate_required_vars() {
    local missing_vars=()
    while IFS='=' read -r key value; do
        if [[ $key != \#* ]] && [[ -z $value ]]; then
            missing_vars+=("$key")
        fi
    done < .env

    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "Warning: The following required variables are empty:"
        printf '%s\n' "${missing_vars[@]}"
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check if .env already exists
if [ -f .env ]; then
    echo "Warning: .env file already exists. Do you want to:"
    echo "1) Keep existing .env file"
    echo "2) Create a new .env file (existing one will be backed up)"
    read -p "Choose an option (1 or 2): " choice
    
    if [ "$choice" = "2" ]; then
        backup_file=".env.backup.$(date +%Y%m%d_%H%M%S)"
        mv .env "$backup_file" || {
            echo "Error: Failed to backup existing .env file"
            exit 1
        }
        echo "Backed up existing .env to $backup_file"
    else
        echo "Keeping existing .env file"
        exit 0
    fi
fi

# Create new .env file
echo "Creating new backend .env file..."

# Basic configuration
cat > .env << EOL
# Server Configuration
PORT=5050
NODE_ENV=production
WEBSITE_HOSTNAME=

# OpenAI Configuration
OPENAI_API_KEY=
OPENAI_MODEL=gpt-3.5-turbo

# YouTube Configuration
YOUTUBE_API_KEY=

# Azure Storage Configuration
AZURE_STORAGE_ACCOUNT_NAME=summarystorage
AZURE_STORAGE_CONNECTION_STRING=
AZURE_STORAGE_CONTAINER_NAME=summary
AZURE_TENANT_ID=
AZURE_CLIENT_ID=
AZURE_CLIENT_SECRET=

# File Size Limits
MAX_FILE_SIZE=524288000  # 500MB
MAX_LOCAL_FILESIZE=209715200  # 200MB
MAX_LOCAL_FILESIZE_MB=100

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000  # 1 minute
RATE_LIMIT_MAX_REQUESTS=10  # 10 requests per minute

# Temporary Directories
TEMP_DIR=
TEMP_VIDEOS_DIR=
TEMP_AUDIOS_DIR=
TEMP_SESSIONS_DIR=

# YouTube cookies (not used currently)
YOUTUBE_COOKIES=
EOL

# Prompt for sensitive information with validation
echo "Please provide the following sensitive information (press Enter to skip):"
prompt_secret "OpenAI API Key" "OPENAI_API_KEY" "validate_api_key"
prompt_secret "YouTube API Key" "YOUTUBE_API_KEY" "validate_api_key"
prompt_secret "Azure Storage Connection String" "AZURE_STORAGE_CONNECTION_STRING" "validate_connection_string"
prompt_secret "Azure Tenant ID" "AZURE_TENANT_ID" "validate_api_key"
prompt_secret "Azure Client ID" "AZURE_CLIENT_ID" "validate_api_key"
prompt_secret "Azure Client Secret" "AZURE_CLIENT_SECRET" "validate_api_key"

# Validate required variables
validate_required_vars

# Set proper permissions
chmod 600 .env

echo "✅ Backend environment setup complete! The .env file has been created with secure permissions."
echo "Make sure to keep this file secure and never commit it to version control." 