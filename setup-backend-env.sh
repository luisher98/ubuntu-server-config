#!/bin/bash

# Function to generate a secure random string
generate_secret() {
    openssl rand -base64 32
}

# Function to prompt for sensitive input
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    local value
    echo -n "$prompt: "
    read -s value
    echo
    echo "$var_name=$value" >> .env
}

# Check if .env already exists
if [ -f .env ]; then
    echo "Warning: .env file already exists. Do you want to:"
    echo "1) Keep existing .env file"
    echo "2) Create a new .env file (existing one will be backed up)"
    read -p "Choose an option (1 or 2): " choice
    
    if [ "$choice" = "2" ]; then
        mv .env .env.backup.$(date +%Y%m%d_%H%M%S)
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

# Prompt for sensitive information
echo "Please provide the following sensitive information (press Enter to skip):"
prompt_secret "OpenAI API Key" "OPENAI_API_KEY"
prompt_secret "YouTube API Key" "YOUTUBE_API_KEY"
prompt_secret "Azure Storage Connection String" "AZURE_STORAGE_CONNECTION_STRING"
prompt_secret "Azure Tenant ID" "AZURE_TENANT_ID"
prompt_secret "Azure Client ID" "AZURE_CLIENT_ID"
prompt_secret "Azure Client Secret" "AZURE_CLIENT_SECRET"

# Set proper permissions
chmod 600 .env

echo "Backend environment setup complete! The .env file has been created with secure permissions."
echo "Make sure to keep this file secure and never commit it to version control." 