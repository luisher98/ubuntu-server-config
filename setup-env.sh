#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run as root"
    exit 1
fi

# Get the current user's home directory
USER_HOME=$(eval echo ~$USER)
APPS_DIR="$USER_HOME/apps"

# Create necessary directories
echo "Creating application directories..."
mkdir -p "$APPS_DIR/video-summary/{backend,frontend,nginx}"

# Copy configuration files
echo "Copying configuration files..."
cp "$APPS_DIR/deployment/nginx.conf" "$APPS_DIR/video-summary/nginx/"
cp "$APPS_DIR/deployment/docker-compose.yml" "$APPS_DIR/video-summary/"

# Clone repositories if they don't exist
if [ ! -d "$APPS_DIR/video-summary/backend" ]; then
    echo "Cloning backend repository..."
    git clone https://github.com/luisher98/video-to-summary-backend.git "$APPS_DIR/video-summary/backend"
fi

if [ ! -d "$APPS_DIR/video-summary/frontend" ]; then
    echo "Cloning frontend repository..."
    git clone https://github.com/luisher98/video-to-summary-frontend.git "$APPS_DIR/video-summary/frontend"
fi

# Set proper permissions
echo "Setting permissions..."
chown -R $USER:$USER "$APPS_DIR/video-summary"

echo "✅ Environment setup complete!"
echo "You can now start the application with:"
echo "cd $APPS_DIR/video-summary"
echo "docker compose up -d" 