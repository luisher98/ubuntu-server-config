#!/bin/bash

# Exit on error
set -e

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <app_name> <env_file_path>"
    echo "Example: $0 backend /home/ubuntu/apps/video-summary/backend/.env"
    exit 1
fi

APP_NAME=$1
ENV_FILE=$2

# Check if apps.yaml exists
if [ ! -f "apps.yaml" ]; then
    echo "Error: apps.yaml not found"
    exit 1
fi

# Check if .env file exists and remove it
if [ -f "$ENV_FILE" ]; then
    echo "Removing existing .env file..."
    rm "$ENV_FILE"
fi

# Get the environment template from apps.yaml
ENV_TEMPLATE=$(yq e ".apps.$APP_NAME.env_template" apps.yaml)
if [ "$ENV_TEMPLATE" = "null" ]; then
    echo "Error: No environment template found for $APP_NAME in apps.yaml"
    exit 1
fi

echo "Please paste all $APP_NAME environment variables at once in the following format:"
echo "$ENV_TEMPLATE"
echo ""
echo "Paste your environment variables below (press Ctrl+D when done):"

# Create the .env file with proper permissions
cat > "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo "Environment variables have been set successfully for $APP_NAME!" 