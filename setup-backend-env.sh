#!/bin/bash

# Exit on error
set -e

# Check if .env file exists and remove it
if [ -f .env ]; then
    echo "Removing existing .env file..."
    rm .env
fi

echo "Please paste all backend environment variables at once in the following format:"
echo "PORT=5050"
echo "NODE_ENV=production"
echo "WEBSITE_HOSTNAME="
echo "OPENAI_API_KEY=your_key_here"
echo "YOUTUBE_API_KEY=your_key_here"
echo "AZURE_STORAGE_ACCOUNT_NAME=summarystorage"
echo "AZURE_STORAGE_CONNECTION_STRING=your_connection_string"
echo "AZURE_STORAGE_CONTAINER_NAME=summary"
echo "AZURE_TENANT_ID=your_tenant_id"
echo "AZURE_CLIENT_ID=your_client_id"
echo "AZURE_CLIENT_SECRET=your_client_secret"
echo "MAX_FILE_SIZE=524288000"
echo "MAX_LOCAL_FILESIZE=209715200"
echo "MAX_LOCAL_FILESIZE_MB=100"
echo "RATE_LIMIT_WINDOW_MS=60000"
echo "RATE_LIMIT_MAX_REQUESTS=10"
echo "TEMP_DIR="
echo "TEMP_VIDEOS_DIR="
echo "TEMP_AUDIOS_DIR="
echo "TEMP_SESSIONS_DIR="
echo ""
echo "Paste your environment variables for the backend below (press Ctrl+D when done):"

# Create a temporary file to store the pasted content
temp_file=$(mktemp)
cat > "$temp_file"

# Create the .env file with proper permissions
cat "$temp_file" > .env
chmod 600 .env
rm "$temp_file"

echo "Backend environment variables have been set successfully!" 