#!/bin/bash

# Exit on error
set -e

# Function to generate a secure random string
generate_secret() {
    openssl rand -base64 32
}

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
echo "Paste your environment variables below (press Ctrl+D when done):"

# Create a temporary file to store the pasted content
temp_file=$(mktemp)
cat > "$temp_file"

# Validate the content
if ! grep -q "^PORT=" "$temp_file"; then
    echo "Error: Missing required variable PORT"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^NODE_ENV=" "$temp_file"; then
    echo "Error: Missing required variable NODE_ENV"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^OPENAI_API_KEY=" "$temp_file"; then
    echo "Error: Missing required variable OPENAI_API_KEY"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^AZURE_STORAGE_CONNECTION_STRING=" "$temp_file"; then
    echo "Error: Missing required variable AZURE_STORAGE_CONNECTION_STRING"
    rm "$temp_file"
    exit 1
fi

# Create the .env file with proper permissions
cat "$temp_file" > .env
chmod 600 .env
rm "$temp_file"

echo "Backend environment variables have been set successfully!" 