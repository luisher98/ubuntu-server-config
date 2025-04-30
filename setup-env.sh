#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run as root"
    exit 1
fi

# Create necessary directories
echo "Creating application directories..."
mkdir -p /home/ubuntu/apps/video-summary/{backend,frontend,nginx}

# Copy configuration files
echo "Copying configuration files..."
cp /home/ubuntu/apps/deployment/nginx.conf /home/ubuntu/apps/video-summary/nginx/
cp /home/ubuntu/apps/deployment/docker-compose.yml /home/ubuntu/apps/video-summary/

# Clone repositories if they don't exist
if [ ! -d "/home/ubuntu/apps/video-summary/backend" ]; then
    echo "Cloning backend repository..."
    git clone https://github.com/luisher98/video-to-summary-backend.git /home/ubuntu/apps/video-summary/backend
fi

if [ ! -d "/home/ubuntu/apps/video-summary/frontend" ]; then
    echo "Cloning frontend repository..."
    git clone https://github.com/luisher98/video-to-summary-frontend.git /home/ubuntu/apps/video-summary/frontend
fi

# Set proper permissions
echo "Setting permissions..."
chown -R $USER:$USER /home/ubuntu/apps/video-summary

echo "✅ Environment setup complete!"
echo "You can now start the application with:"
echo "cd /home/ubuntu/apps/video-summary"
echo "docker compose up -d" 