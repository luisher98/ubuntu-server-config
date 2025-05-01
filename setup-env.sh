#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run as root"
    exit 1
fi

# Get the current directory
CURRENT_DIR=$(pwd)
echo "Current directory: $CURRENT_DIR"

# Create docker-compose.yml if it doesn't exist
if [ ! -f "docker-compose.yml" ]; then
    echo "Creating docker-compose.yml..."
    cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "5050:5050"
    environment:
      - NODE_ENV=production
    volumes:
      - ./backend:/app
      - /app/node_modules
    networks:
      - video-summary-network
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5050/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    volumes:
      - ./frontend:/app
      - /app/node_modules
    networks:
      - video-summary-network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.2'
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    networks:
      - video-summary-network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.2'
          memory: 128M
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  video-summary-network:
    driver: bridge
EOL
    chmod 644 docker-compose.yml
    echo "docker-compose.yml created successfully"
fi

# Create .env files if they don't exist
if [ ! -f "backend/.env" ]; then
    echo "Creating backend/.env..."
    cat > backend/.env << 'EOL'
NODE_ENV=production
PORT=5050
EOL
    chmod 644 backend/.env
    echo "backend/.env created successfully"
fi

if [ ! -f "frontend/.env" ]; then
    echo "Creating frontend/.env..."
    cat > frontend/.env << 'EOL'
NODE_ENV=production
PORT=3000
EOL
    chmod 644 frontend/.env
    echo "frontend/.env created successfully"
fi

# Create certbot directories if they don't exist
mkdir -p nginx/certbot/conf
mkdir -p nginx/certbot/www
chmod 755 nginx/certbot
chmod 755 nginx/certbot/conf
chmod 755 nginx/certbot/www

echo "✅ Environment setup complete!"
echo "You can now start the applications with: docker compose up -d" 