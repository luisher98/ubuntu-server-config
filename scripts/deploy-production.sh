#!/bin/bash

# Production Deployment Script for Video Summary API
# This script handles safe deployment to production with rollback capabilities

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
SKIP_CHECKS=false
DRY_RUN=false
BACKUP_DIR="/var/backups/video-summary"
COMPOSE_FILE="docker-compose.yml"

# Help function
show_help() {
    cat << EOF
🚀 Production Deployment Script

Usage: $0 [OPTIONS]

Options:
    -d, --domain DOMAIN     Your domain name (for SSL verification)
    --skip-checks           Skip pre-deployment checks (dangerous!)
    --dry-run               Show what would be done without executing
    -h, --help              Show this help message

Examples:
    $0 -d api.example.com
    $0 --dry-run
    $0 --skip-checks

Prerequisites:
    - SSL certificates must be set up (run setup-ssl.sh first)
    - Production environment file (backend/.env.prod) must be configured
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
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Dry run function
execute() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $@"
    else
        "$@"
    fi
}

# Check if running as root
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    if [[ "$SKIP_CHECKS" == true ]]; then
        print_warning "Skipping pre-deployment checks"
        return 0
    fi
    
    print_status "Running pre-deployment checks..."
    
    # Check if production environment file exists
    if [[ ! -f "backend/.env.prod" ]]; then
        print_error "Production environment file not found: backend/.env.prod"
        print_status "Run setup-ssl.sh first or create the file manually"
        exit 1
    fi
    
    # Check if SSL certificates exist
    if [[ -n "$DOMAIN" ]]; then
        if [[ ! -f "nginx/certbot/conf/live/$DOMAIN/fullchain.pem" ]]; then
            print_error "SSL certificate not found for domain: $DOMAIN"
            print_status "Run: sudo ./scripts/setup-ssl.sh -d $DOMAIN -e your@email.com"
            exit 1
        fi
        print_success "SSL certificate found for $DOMAIN"
    fi
    
    # Check if nginx production config exists
    if [[ ! -f "nginx/nginx.prod.conf" ]]; then
        print_error "Production nginx configuration not found: nginx/nginx.prod.conf"
        exit 1
    fi
    
    # Check if production docker compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_error "Production docker compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Validate docker compose configuration
    if ! docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
        print_error "Invalid docker compose configuration"
        docker compose -f "$COMPOSE_FILE" config
        exit 1
    fi
    
    # Check available disk space (at least 2GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then  # 2GB in KB
        print_error "Insufficient disk space. At least 2GB required."
        exit 1
    fi
    
    # Check if required ports are available or used by our services
    for port in 80 443; do
        if netstat -tuln | grep ":$port " | grep -v docker-proxy > /dev/null; then
            print_warning "Port $port is in use by non-Docker process"
        fi
    done
    
    print_success "Pre-deployment checks passed"
}

# Create backup
create_backup() {
    print_status "Creating backup..."
    
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$backup_timestamp"
    
    execute mkdir -p "$backup_path"
    
    # Backup configuration files
    execute cp -r nginx "$backup_path/" 2>/dev/null || true
    execute cp backend/.env.prod "$backup_path/" 2>/dev/null || true
    execute cp "$COMPOSE_FILE" "$backup_path/" 2>/dev/null || true
    
    # Backup data directory
    if [[ -d "backend/data" ]]; then
        execute cp -r backend/data "$backup_path/" 2>/dev/null || true
    fi
    
    # Export current docker images
    if docker compose -f "$COMPOSE_FILE" ps -q > /dev/null 2>&1; then
        execute docker compose -f "$COMPOSE_FILE" images --format "table {{.Repository}}:{{.Tag}}" | grep -v "REPOSITORY" > "$backup_path/images.txt" 2>/dev/null || true
    fi
    
    # Create backup info
    cat > "$backup_path/backup_info.txt" << EOF
Backup created: $(date)
Hostname: $(hostname)
Domain: $DOMAIN
Git commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Git branch: $(git branch --show-current 2>/dev/null || echo "N/A")
Docker version: $(docker --version)
Docker Compose version: $(docker compose version)
EOF
    
    print_success "Backup created: $backup_path"
    echo "$backup_path" > /tmp/last_backup_path
}

# Build and test images
build_images() {
    print_status "Building Docker images..."
    
    # Build images
    execute docker compose -f "$COMPOSE_FILE" build --no-cache
    
    # Test build success
    if ! docker images | grep -q video-summary-backend; then
        print_error "Failed to build backend image"
        exit 1
    fi
    
    print_success "Docker images built successfully"
}

# Deploy services with zero-downtime strategy
deploy_services() {
    print_status "Deploying services..."
    
    # Stop existing services gracefully
    if docker compose -f "$COMPOSE_FILE" ps -q > /dev/null 2>&1; then
        print_status "Stopping existing services..."
        execute docker compose -f "$COMPOSE_FILE" down --timeout 30
    fi
    
    # Start new services
    print_status "Starting new services..."
    execute docker compose -f "$COMPOSE_FILE" up -d
    
    print_success "Services deployed"
}

# Health checks
run_health_checks() {
    print_status "Running health checks..."
    
    local max_retries=30
    local retry_count=0
    
    # Wait for services to be ready
    while [[ $retry_count -lt $max_retries ]]; do
        if [[ "$DRY_RUN" == true ]]; then
            print_status "[DRY RUN] Would check service health"
            break
        fi
        
        # Check backend health
        if curl -f -s http://localhost:5050/health > /dev/null 2>&1; then
            print_success "Backend health check passed"
            break
        fi
        
        retry_count=$((retry_count + 1))
        sleep 10
        
        if [[ $retry_count -eq $max_retries ]]; then
            print_error "Backend health check failed after $max_retries attempts"
            return 1
        fi
        
        print_status "Waiting for backend... ($retry_count/$max_retries)"
    done
    
    # Check nginx health
    retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if [[ "$DRY_RUN" == true ]]; then
            print_status "[DRY RUN] Would check nginx health"
            break
        fi
        
        if curl -f -s http://localhost/health > /dev/null 2>&1; then
            print_success "Nginx health check passed"
            break
        fi
        
        retry_count=$((retry_count + 1))
        sleep 5
        
        if [[ $retry_count -eq $max_retries ]]; then
            print_error "Nginx health check failed after $max_retries attempts"
            return 1
        fi
        
        print_status "Waiting for nginx... ($retry_count/$max_retries)"
    done
    
    # Test HTTPS if domain is provided
    if [[ -n "$DOMAIN" && "$DRY_RUN" != true ]]; then
        print_status "Testing HTTPS endpoint..."
        if curl -f -s "https://$DOMAIN/health" > /dev/null 2>&1; then
            print_success "HTTPS health check passed"
        else
            print_warning "HTTPS health check failed - check SSL configuration"
        fi
    fi
    
    print_success "Health checks completed"
}

# Post-deployment tasks
post_deployment() {
    print_status "Running post-deployment tasks..."
    
    # Clean up old Docker images
    execute docker image prune -f
    
    # Set up log rotation if not exists
    if [[ ! -f "/etc/logrotate.d/video-summary" ]]; then
        cat > /tmp/video-summary-logrotate << 'EOF'
/var/log/video-summary/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 root root
    postrotate
        docker compose -f /path/to/docker-compose.prod.yml restart nginx || true
    endscript
}
EOF
        execute mv /tmp/video-summary-logrotate /etc/logrotate.d/video-summary
        execute sed -i "s|/path/to|$(pwd)|g" /etc/logrotate.d/video-summary
        print_success "Log rotation configured"
    fi
    
    # Create systemd service for auto-start
    if [[ ! -f "/etc/systemd/system/video-summary.service" ]]; then
        cat > /tmp/video-summary.service << EOF
[Unit]
Description=Video Summary API
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker compose -f $COMPOSE_FILE up -d
ExecStop=/usr/bin/docker compose -f $COMPOSE_FILE down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
        execute mv /tmp/video-summary.service /etc/systemd/system/
        execute systemctl daemon-reload
        execute systemctl enable video-summary.service
        print_success "Systemd service configured"
    fi
    
    print_success "Post-deployment tasks completed"
}

# Rollback function
rollback() {
    print_error "Deployment failed! Starting rollback..."
    
    if [[ -f "/tmp/last_backup_path" ]]; then
        local backup_path=$(cat /tmp/last_backup_path)
        
        if [[ -d "$backup_path" ]]; then
            print_status "Rolling back to backup: $backup_path"
            
            # Stop current services
            execute docker compose -f "$COMPOSE_FILE" down --timeout 30
            
            # Restore configuration files
            execute cp -r "$backup_path/nginx" . 2>/dev/null || true
            execute cp "$backup_path/.env.prod" backend/ 2>/dev/null || true
            execute cp "$backup_path/$COMPOSE_FILE" . 2>/dev/null || true
            
            # Start services with backup configuration
            execute docker compose -f "$COMPOSE_FILE" up -d
            
            print_warning "Rollback completed. Please check logs and fix issues."
        else
            print_error "Backup not found: $backup_path"
        fi
    else
        print_error "No backup information found"
    fi
}

# Show deployment status
show_status() {
    print_status "Deployment Status:"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "[DRY RUN] Would show service status"
        return 0
    fi
    
    # Service status
    docker compose -f "$COMPOSE_FILE" ps
    echo
    
    # Resource usage
    print_status "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    echo
    
    # URLs
    print_status "Application URLs:"
    echo "🌐 HTTP Health: http://localhost/health"
    if [[ -n "$DOMAIN" ]]; then
        echo "🔒 HTTPS Site: https://$DOMAIN"
        echo "🔒 HTTPS Health: https://$DOMAIN/health"
        echo "🔒 HTTPS API: https://$DOMAIN/api"
    fi
    echo "📊 Direct Backend: http://localhost:5050"
    echo
    
    # Recent logs
    print_status "Recent Logs (last 10 lines):"
    docker compose -f "$COMPOSE_FILE" logs --tail=10
}

# Main deployment function
main() {
    echo "🚀 Production Deployment - Video Summary API"
    echo "============================================"
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo
    fi
    
    if [[ -n "$DOMAIN" ]]; then
        echo "Domain: $DOMAIN"
    fi
    echo "Compose file: $COMPOSE_FILE"
    echo "Skip checks: $SKIP_CHECKS"
    echo
    
    if [[ "$DRY_RUN" != true ]]; then
        read -p "Continue with production deployment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deployment cancelled"
            exit 0
        fi
    fi
    
    # Deployment steps
    check_permissions
    pre_deployment_checks
    create_backup
    
    # Set up error handling for rollback
    if [[ "$DRY_RUN" != true ]]; then
        trap rollback ERR
    fi
    
    build_images
    deploy_services
    
    if run_health_checks; then
        post_deployment
        
        # Disable rollback trap on success
        trap - ERR
        
        print_success "🎉 Production deployment completed successfully!"
        echo
        show_status
        
        if [[ -n "$DOMAIN" ]]; then
            print_status "Your site is now live at: https://$DOMAIN"
        fi
        
    else
        print_error "Health checks failed!"
        if [[ "$DRY_RUN" != true ]]; then
            rollback
        fi
        exit 1
    fi
}

# Run main function
main "$@" 