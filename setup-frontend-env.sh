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
echo "Creating new frontend .env file..."

# Basic configuration
cat > .env << EOL
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:5050

# Azure Storage Configuration
NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME=summarystorage
NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME=summary
NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN=

# App Configuration
NEXT_PUBLIC_MAX_FILE_SIZE=524288000  # 500MB in bytes
NEXT_PUBLIC_MAX_LOCAL_FILESIZE=209715200  # 200MB in bytes

# Optional - YouTube API Configuration
GOOGLE_API_KEY=
EOL

# Prompt for sensitive information
echo "Please provide the following sensitive information (press Enter to skip):"
prompt_secret "Azure Storage SAS Token" "NEXT_PUBLIC_AZURE_STORAGE_SAS_TOKEN"
prompt_secret "Google API Key (optional)" "GOOGLE_API_KEY"

# Set proper permissions
chmod 600 .env

echo "Frontend environment setup complete! The .env file has been created with secure permissions."
echo "Make sure to keep this file secure and never commit it to version control." 