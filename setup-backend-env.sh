#!/bin/bash

# Exit on error
set -e

# Check if .env file exists and remove it
if [ -f .env ]; then
    echo "Removing existing .env file..."
    rm .env
fi

echo "Please paste all backend environment variables at once in the following format:"
echo "# Server Configuration"
echo "PORT=5050"
echo "NODE_ENV=production"
echo "WEBSITE_HOSTNAME="
echo ""
echo "# OpenAI Configuration"
echo "OPENAI_API_KEY=your_key_here"
echo "OPENAI_MODEL=gpt-3.5-turbo"
echo ""
echo "# YouTube Configuration"
echo "YOUTUBE_API_KEY=your_key_here"
echo ""
echo "# Azure Storage Configuration"
echo "AZURE_STORAGE_ACCOUNT_NAME=summarystorage"
echo "AZURE_STORAGE_CONNECTION_STRING=your_connection_string"
echo "AZURE_STORAGE_CONTAINER_NAME=summary"
echo "AZURE_TENANT_ID=your_tenant_id"
echo "AZURE_CLIENT_ID=your_client_id"
echo "AZURE_CLIENT_SECRET=your_client_secret"
echo ""
echo "# File Size Limits"
echo "MAX_FILE_SIZE=524288000  # 500MB"
echo "MAX_LOCAL_FILESIZE=209715200  # 200MB"
echo "MAX_LOCAL_FILESIZE_MB=100"
echo ""
echo "# Rate Limiting"
echo "RATE_LIMIT_WINDOW_MS=60000  # 1 minute"
echo "RATE_LIMIT_MAX_REQUESTS=10  # 10 requests per minute"
echo ""
echo "# Temporary Directories"
echo "TEMP_DIR="
echo "TEMP_VIDEOS_DIR="
echo "TEMP_AUDIOS_DIR="
echo "TEMP_SESSIONS_DIR="
echo ""
echo "Paste your environment variables for the backend below (press Ctrl+D when done):"

# Create a temporary file to store the pasted content
temp_file=$(mktemp)
cat > "$temp_file"

# Validate the format
if ! validate_env_format "$temp_file"; then
    echo "Error: Environment file format validation failed"
    rm "$temp_file"
    exit 1
fi

# Create the .env file with proper permissions
cat "$temp_file" > .env
chmod 600 .env
rm "$temp_file"

echo "Backend environment variables have been set successfully!"