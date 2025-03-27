#!/bin/bash

# Exit on error
set -e

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
echo "Creating new frontend .env file..."

# Basic configuration
cat > .env << EOL
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:5050
NEXT_PUBLIC_API_VERSION=v1

# Azure Storage Configuration
NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME=summarystorage
NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING=
NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME=summary

# YouTube API Configuration (Optional)
NEXT_PUBLIC_YOUTUBE_API_KEY=

# Application Settings
NEXT_PUBLIC_MAX_FILE_SIZE=524288000  # 500MB
NEXT_PUBLIC_MAX_LOCAL_FILESIZE=209715200  # 200MB
NEXT_PUBLIC_SUPPORTED_VIDEO_FORMATS=mp4,webm,ogg
NEXT_PUBLIC_SUPPORTED_AUDIO_FORMATS=mp3,wav,ogg
EOL

# Prompt for sensitive information
echo "Please provide the following sensitive information (press Enter to skip):"
prompt_secret "Azure Storage Connection String" "NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING"
prompt_secret "YouTube API Key (Optional)" "NEXT_PUBLIC_YOUTUBE_API_KEY"

# Validate required variables
validate_required_vars

# Set proper permissions
chmod 600 .env

echo "✅ Frontend environment setup complete! The .env file has been created with secure permissions."
echo "Make sure to keep this file secure and never commit it to version control." 