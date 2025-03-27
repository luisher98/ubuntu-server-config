#!/bin/bash

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

# Check if .env file exists
if [ -f .env ]; then
    echo "Warning: .env file already exists"
    read -p "Do you want to backup the existing .env file? (y/n): " backup
    if [ "$backup" = "y" ]; then
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backup created"
    fi
fi

echo "Please paste all deployment environment variables at once in the following format:"
echo "NODE_ENV=production"
echo "PORT=5000"
echo "BACKEND_URL=http://localhost:5000"
echo "FRONTEND_URL=http://localhost:3000"
echo "JWT_SECRET=<generate_secure_random_string>"
echo "API_KEY=<generate_secure_random_string>"
echo "DATABASE_URL=<if_needed>"
echo "AWS_ACCESS_KEY_ID=<if_needed>"
echo "AWS_SECRET_ACCESS_KEY=<if_needed>"
echo "AWS_REGION=<if_needed>"
echo "SMTP_HOST=<if_needed>"
echo "SMTP_PORT=<if_needed>"
echo "SMTP_USER=<if_needed>"
echo "SMTP_PASS=<if_needed>"
echo ""
echo "Paste your environment variables below (press Ctrl+D when done):"

# Create a temporary file to store the pasted content
temp_file=$(mktemp)
cat > "$temp_file"

# Validate the content
if ! grep -q "^NODE_ENV=" "$temp_file"; then
    echo "Error: Missing required variable NODE_ENV"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^PORT=" "$temp_file"; then
    echo "Error: Missing required variable PORT"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^BACKEND_URL=" "$temp_file"; then
    echo "Error: Missing required variable BACKEND_URL"
    rm "$temp_file"
    exit 1
fi

if ! grep -q "^FRONTEND_URL=" "$temp_file"; then
    echo "Error: Missing required variable FRONTEND_URL"
    rm "$temp_file"
    exit 1
fi

# Create the .env file with proper permissions
cat "$temp_file" > .env
chmod 600 .env
rm "$temp_file"

echo "Deployment environment variables have been set successfully!" 