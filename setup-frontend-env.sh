#!/bin/bash

# Exit on error
set -e

# Function to generate a secure random string
generate_secret() {
    openssl rand -base64 32
}

# Function to prompt for sensitive information
prompt_for_sensitive() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local value

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        read -p "$prompt: " value
    fi

    echo "$value"
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

# Check if .env file exists
if [ -f .env ]; then
    echo "Warning: .env file already exists"
    read -p "Do you want to backup the existing .env file? (y/n): " backup
    if [ "$backup" = "y" ]; then
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backup created"
    fi
fi

echo "Please paste all frontend environment variables at once in the following format:"
echo "NEXT_PUBLIC_API_URL=/api"
echo "NEXT_PUBLIC_API_VERSION=v1"
echo "NEXT_PUBLIC_AZURE_STORAGE_ACCOUNT_NAME=summarystorage"
echo "NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING=your_connection_string"
echo "NEXT_PUBLIC_AZURE_STORAGE_CONTAINER_NAME=summary"
echo "NEXT_PUBLIC_YOUTUBE_API_KEY=your_youtube_api_key"
echo "NEXT_PUBLIC_MAX_FILE_SIZE=524288000"
echo "NEXT_PUBLIC_MAX_LOCAL_FILESIZE=209715200"
echo "NEXT_PUBLIC_SUPPORTED_VIDEO_FORMATS=mp4,webm,ogg"
echo "NEXT_PUBLIC_SUPPORTED_AUDIO_FORMATS=mp3,wav,ogg"
echo ""
echo "Paste your environment variables below (press Ctrl+D when done):"

# Create a temporary file to store the pasted content
temp_file=$(mktemp)
cat > "$temp_file"

# Validate the content
if ! grep -q "^NEXT_PUBLIC_API_URL=" "$temp_file"; then
    echo "Error: Missing required variable NEXT_PUBLIC_API_URL"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING=" "$temp_file"; then
    echo "Error: Missing required variable NEXT_PUBLIC_AZURE_STORAGE_CONNECTION_STRING"
    rm "$temp_file"
    exit 1
fi

# Create the .env file with proper permissions
cat "$temp_file" > .env
chmod 600 .env
rm "$temp_file"

# Validate required variables
validate_required_vars

echo "Frontend environment variables have been set successfully!" 