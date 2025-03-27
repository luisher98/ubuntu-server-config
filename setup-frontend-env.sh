#!/usr/bin/env bash

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
echo "Paste your environment variables for the frontend below (press Ctrl+D when done):"

# Create a temporary file to store the pasted content
temp_file=$(mktemp)
cat > "$temp_file"


# Create the .env file with proper permissions
cat "$temp_file" > .env
chmod 600 .env
rm "$temp_file"

echo "Frontend environment variables have been set successfully!" 