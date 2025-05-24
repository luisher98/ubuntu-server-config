#!/bin/bash

# SSL Certificate Setup Script for Video Summary API
# This script sets up Let's Encrypt SSL certificates for production

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
DOMAIN=""
EMAIL=""
STAGING=false

# Help function
show_help() {
    cat << EOF
🔐 SSL Certificate Setup Script

Usage: $0 -d DOMAIN -e EMAIL [OPTIONS]

Options:
    -d, --domain DOMAIN     Your domain name (e.g., api.yourdomain.com)
    -e, --email EMAIL       Email for Let's Encrypt notifications
    -s, --staging           Use Let's Encrypt staging environment (for testing)
    -h, --help              Show this help message

Examples:
    $0 -d api.example.com -e admin@example.com
    $0 -d api.example.com -e admin@example.com --staging

Prerequisites:
    - Domain must point to this server's IP address
    - Ports 80 and 443 must be open
    - Docker and Docker Compose must be installed
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -s|--staging)
            STAGING=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    print_error "Domain and email are required!"
    show_help
    exit 1
fi

print_status "🔐 Setting up SSL certificates for $DOMAIN"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check if domain resolves to this server
    print_status "Checking DNS resolution for $DOMAIN..."
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "unknown")
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
    
    if [[ "$SERVER_IP" != "$DOMAIN_IP" ]]; then
        print_warning "Domain $DOMAIN resolves to $DOMAIN_IP but server IP is $SERVER_IP"
        print_warning "Make sure your domain points to this server!"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "DNS resolution OK: $DOMAIN → $SERVER_IP"
    fi
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check if ports are available
    if netstat -tuln | grep -q ":80 "; then
        print_warning "Port 80 is already in use"
    fi
    
    if netstat -tuln | grep -q ":443 "; then
        print_warning "Port 443 is already in use"
    fi
    
    print_success "Prerequisites check completed"
}

# Create directory structure
setup_directories() {
    print_status "Setting up directory structure..."
    
    mkdir -p nginx/certbot/conf
    mkdir -p nginx/certbot/www
    mkdir -p nginx/ssl
    
    # Set proper permissions
    chmod 755 nginx/certbot/conf
    chmod 755 nginx/certbot/www
    
    print_success "Directories created"
}

# Update nginx configuration with domain
update_nginx_config() {
    print_status "Updating nginx configuration..."
    
    if [[ ! -f "nginx/nginx.prod.conf" ]]; then
        print_error "nginx/nginx.prod.conf not found!"
        exit 1
    fi
    
    # Create backup
    cp nginx/nginx.prod.conf nginx/nginx.prod.conf.backup
    
    # Replace domain placeholder
    sed -i "s/YOUR_DOMAIN_HERE/$DOMAIN/g" nginx/nginx.prod.conf
    
    print_success "Nginx configuration updated for domain: $DOMAIN"
}

# Create temporary nginx config for certificate request
create_temp_nginx_config() {
    print_status "Creating temporary nginx configuration..."
    
    cat > nginx/nginx.temp.conf << EOF
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name $DOMAIN;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 200 'SSL certificate setup in progress...';
            add_header Content-Type text/plain;
        }
    }
}
EOF
}

# Start temporary nginx for certificate generation
start_temp_nginx() {
    print_status "Starting temporary nginx for certificate generation..."
    
    # Stop any existing containers
    docker compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # Start nginx with temporary config
    docker run -d \
        --name nginx-temp \
        -p 80:80 \
        -v "$(pwd)/nginx/nginx.temp.conf:/etc/nginx/nginx.conf:ro" \
        -v "$(pwd)/nginx/certbot/www:/var/www/certbot:ro" \
        nginx:alpine
    
    # Wait for nginx to start
    sleep 5
    
    # Test if nginx is responding
    if curl -f -s "http://$DOMAIN/" > /dev/null; then
        print_success "Temporary nginx is running"
    else
        print_error "Nginx is not responding on port 80"
        docker logs nginx-temp
        exit 1
    fi
}

# Generate SSL certificate
generate_certificate() {
    print_status "Generating SSL certificate..."
    
    # Prepare certbot command
    CERTBOT_CMD="certonly --webroot --webroot-path=/var/www/certbot --email $EMAIL --agree-tos --no-eff-email"
    
    if [[ "$STAGING" == true ]]; then
        print_warning "Using Let's Encrypt staging environment"
        CERTBOT_CMD="$CERTBOT_CMD --staging"
    fi
    
    CERTBOT_CMD="$CERTBOT_CMD -d $DOMAIN"
    
    # Run certbot
    print_status "Running certbot..."
    docker run --rm \
        -v "$(pwd)/nginx/certbot/conf:/etc/letsencrypt" \
        -v "$(pwd)/nginx/certbot/www:/var/www/certbot" \
        certbot/certbot:latest $CERTBOT_CMD
    
    # Check if certificate was generated
    if [[ -f "nginx/certbot/conf/live/$DOMAIN/fullchain.pem" ]]; then
        print_success "SSL certificate generated successfully!"
    else
        print_error "Failed to generate SSL certificate"
        exit 1
    fi
}

# Stop temporary nginx
stop_temp_nginx() {
    print_status "Stopping temporary nginx..."
    docker stop nginx-temp 2>/dev/null || true
    docker rm nginx-temp 2>/dev/null || true
}

# Test SSL certificate
test_certificate() {
    print_status "Testing SSL certificate..."
    
    # Check certificate validity
    openssl x509 -in "nginx/certbot/conf/live/$DOMAIN/fullchain.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
    
    print_success "Certificate information displayed above"
}

# Create production environment file
create_production_env() {
    print_status "Creating production environment template..."
    
    if [[ ! -f "backend/.env.prod" ]]; then
        cat > backend/.env.prod << EOF
# Production Environment Configuration
# IMPORTANT: Update all values before deployment!

# OpenAI Configuration
OPENAI_API_KEY=your_production_openai_key
OPENAI_MODEL=gpt-4

# YouTube API
YOUTUBE_API_KEY=your_production_youtube_key

# Azure Storage Configuration
AZURE_STORAGE_AUTH_TYPE=servicePrincipal
AZURE_STORAGE_ACCOUNT_NAME=your_production_storage_account
AZURE_STORAGE_CONTAINER_NAME=summary
AZURE_STORAGE_ACCOUNT_KEY=your_production_storage_key
AZURE_TENANT_ID=your_production_tenant_id
AZURE_CLIENT_ID=your_production_client_id
AZURE_CLIENT_SECRET=your_production_client_secret

# Application Configuration
MAX_FILE_SIZE=100MB
MAX_LOCAL_FILESIZE=104857600
MAX_LOCAL_FILESIZE_MB=100
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=50

# Environment
NODE_ENV=production

# Admin Configuration
ADMIN_EMAIL=$EMAIL
DOMAIN=$DOMAIN
EOF
        print_success "Production environment template created: backend/.env.prod"
        print_warning "Please update backend/.env.prod with your actual production values!"
    else
        print_warning "Production environment file already exists"
    fi
}

# Create certificate renewal script
create_renewal_script() {
    print_status "Creating certificate renewal script..."
    
    cat > scripts/renew-ssl.sh << 'EOF'
#!/bin/bash

# SSL Certificate Renewal Script
# Add this to crontab: 0 12 * * * /path/to/renew-ssl.sh

cd "$(dirname "$0")/.."

echo "$(date): Starting SSL certificate renewal"

# Renew certificates
docker compose -f docker-compose.prod.yml run --rm certbot renew

# Reload nginx if certificate was renewed
if [ $? -eq 0 ]; then
    echo "$(date): Certificate renewal successful, reloading nginx"
    docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
else
    echo "$(date): Certificate renewal failed"
    exit 1
fi

echo "$(date): SSL certificate renewal completed"
EOF
    
    chmod +x scripts/renew-ssl.sh
    print_success "Certificate renewal script created: scripts/renew-ssl.sh"
    
    print_status "Add this to crontab for automatic renewal:"
    echo "0 12 * * * $(pwd)/scripts/renew-ssl.sh >> /var/log/letsencrypt-renew.log 2>&1"
}

# Main execution
main() {
    echo "🔐 SSL Certificate Setup for Video Summary API"
    echo "=============================================="
    echo
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo "Staging: $STAGING"
    echo
    
    read -p "Continue with SSL setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "SSL setup cancelled"
        exit 0
    fi
    
    check_prerequisites
    setup_directories
    update_nginx_config
    create_temp_nginx_config
    start_temp_nginx
    
    # Generate certificate
    if generate_certificate; then
        stop_temp_nginx
        test_certificate
        create_production_env
        create_renewal_script
        
        print_success "🎉 SSL setup completed successfully!"
        echo
        print_status "Next steps:"
        echo "1. Update backend/.env.prod with your production values"
        echo "2. Start production services: docker compose -f docker-compose.prod.yml up -d"
        echo "3. Test your site: https://$DOMAIN"
        echo "4. Add renewal script to crontab for automatic certificate renewal"
        echo
        print_status "Your site should now be available at: https://$DOMAIN"
        
    else
        stop_temp_nginx
        print_error "SSL setup failed"
        exit 1
    fi
}

# Run main function
main "$@" 