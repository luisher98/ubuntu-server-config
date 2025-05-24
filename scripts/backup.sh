#!/bin/bash

# Backup Script for Video Summary API
# This script creates comprehensive backups of the production environment

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
BACKUP_DIR="/var/backups/video-summary"
RETENTION_DAYS=30
COMPRESS=true
REMOTE_BACKUP=""
S3_BUCKET=""

# Help function
show_help() {
    cat << EOF
💾 Backup Script for Video Summary API

Usage: $0 [OPTIONS]

Options:
    --retention DAYS        Number of days to keep backups (default: 30)
    --no-compress          Don't compress backup files
    --remote HOST:PATH     Upload to remote server via rsync
    --s3 BUCKET            Upload to S3 bucket
    -h, --help             Show this help message

Examples:
    $0                                    # Basic backup
    $0 --retention 7                     # Keep 7 days
    $0 --remote backup@server:/backups   # Upload to remote server
    $0 --s3 my-backup-bucket            # Upload to S3

Prerequisites:
    - Running as root or with sudo
    - Docker and Docker Compose installed
    - For S3: aws-cli configured
    - For remote: SSH key authentication
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --remote)
            REMOTE_BACKUP="$2"
            shift 2
            ;;
        --s3)
            S3_BUCKET="$2"
            shift 2
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

# Check permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Create backup directory
setup_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "Failed to create backup directory: $BACKUP_DIR"
        exit 1
    fi
}

# Generate timestamp
get_timestamp() {
    date +%Y%m%d_%H%M%S
}

# Backup application data
backup_application_data() {
    local timestamp=$(get_timestamp)
    local backup_path="$BACKUP_DIR/app_data_$timestamp"
    
    print_status "Creating application data backup..."
    mkdir -p "$backup_path"
    
    # Backup data directory
    if [[ -d "backend/data" ]]; then
        cp -r backend/data "$backup_path/" 2>/dev/null || print_warning "Failed to backup data directory"
    fi
    
    # Backup configuration files
    cp backend/.env.prod "$backup_path/" 2>/dev/null || print_warning "Failed to backup .env.prod"
    cp docker-compose.prod.yml "$backup_path/" 2>/dev/null || print_warning "Failed to backup docker-compose.prod.yml"
    cp -r nginx "$backup_path/" 2>/dev/null || print_warning "Failed to backup nginx config"
    
    # Create backup manifest
    cat > "$backup_path/manifest.txt" << EOF
Backup Type: Application Data
Created: $(date)
Hostname: $(hostname)
Git Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Git Branch: $(git branch --show-current 2>/dev/null || echo "N/A")
Docker Images:
$(docker compose -f docker-compose.prod.yml images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || echo "N/A")
EOF
    
    print_success "Application data backup created: $backup_path"
    echo "$backup_path"
}

# Backup SSL certificates
backup_ssl_certificates() {
    local timestamp=$(get_timestamp)
    local backup_path="$BACKUP_DIR/ssl_$timestamp"
    
    if [[ -d "nginx/certbot/conf/live" ]]; then
        print_status "Creating SSL certificates backup..."
        mkdir -p "$backup_path"
        
        cp -r nginx/certbot/conf "$backup_path/" 2>/dev/null || print_warning "Failed to backup SSL certificates"
        
        # Create SSL backup manifest
        cat > "$backup_path/ssl_manifest.txt" << EOF
Backup Type: SSL Certificates
Created: $(date)
Hostname: $(hostname)
Certificates:
$(find nginx/certbot/conf/live -name "*.pem" 2>/dev/null | head -10 || echo "N/A")
EOF
        
        print_success "SSL certificates backup created: $backup_path"
        echo "$backup_path"
    else
        print_warning "No SSL certificates found to backup"
    fi
}

# Export Docker images
backup_docker_images() {
    local timestamp=$(get_timestamp)
    local backup_path="$BACKUP_DIR/docker_$timestamp"
    
    print_status "Creating Docker images backup..."
    mkdir -p "$backup_path"
    
    # Export custom images
    if docker images | grep -q video-summary; then
        docker save video-summary-backend:latest | gzip > "$backup_path/backend_image.tar.gz" 2>/dev/null || print_warning "Failed to export backend image"
    fi
    
    # Save image list
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" > "$backup_path/images_list.txt" 2>/dev/null || true
    
    print_success "Docker images backup created: $backup_path"
    echo "$backup_path"
}

# Backup database (if applicable)
backup_database() {
    local timestamp=$(get_timestamp)
    local backup_path="$BACKUP_DIR/db_$timestamp"
    
    # Check if database containers are running
    if docker compose -f docker-compose.prod.yml ps | grep -q postgres; then
        print_status "Creating database backup..."
        mkdir -p "$backup_path"
        
        # PostgreSQL backup
        docker compose -f docker-compose.prod.yml exec postgres pg_dumpall -U postgres | gzip > "$backup_path/postgres_dump.sql.gz" 2>/dev/null || print_warning "Failed to backup PostgreSQL"
        
        print_success "Database backup created: $backup_path"
        echo "$backup_path"
    fi
    
    if docker compose -f docker-compose.prod.yml ps | grep -q redis; then
        print_status "Creating Redis backup..."
        mkdir -p "$backup_path"
        
        # Redis backup
        docker compose -f docker-compose.prod.yml exec redis redis-cli BGSAVE
        sleep 5
        docker cp "$(docker compose -f docker-compose.prod.yml ps -q redis):/data/dump.rdb" "$backup_path/redis_dump.rdb" 2>/dev/null || print_warning "Failed to backup Redis"
        
        print_success "Redis backup created: $backup_path"
    fi
}

# Compress backups
compress_backup() {
    local backup_path="$1"
    
    if [[ "$COMPRESS" == true && -d "$backup_path" ]]; then
        print_status "Compressing backup: $(basename "$backup_path")"
        
        local compressed_file="${backup_path}.tar.gz"
        tar -czf "$compressed_file" -C "$(dirname "$backup_path")" "$(basename "$backup_path")" 2>/dev/null
        
        if [[ -f "$compressed_file" ]]; then
            rm -rf "$backup_path"
            print_success "Backup compressed: $compressed_file"
            echo "$compressed_file"
        else
            print_warning "Failed to compress backup"
            echo "$backup_path"
        fi
    else
        echo "$backup_path"
    fi
}

# Upload to remote server
upload_to_remote() {
    local backup_file="$1"
    
    if [[ -n "$REMOTE_BACKUP" && -e "$backup_file" ]]; then
        print_status "Uploading to remote server: $REMOTE_BACKUP"
        
        rsync -avz --progress "$backup_file" "$REMOTE_BACKUP/" 2>/dev/null || {
            print_warning "Failed to upload to remote server"
            return 1
        }
        
        print_success "Backup uploaded to remote server"
    fi
}

# Upload to S3
upload_to_s3() {
    local backup_file="$1"
    
    if [[ -n "$S3_BUCKET" && -e "$backup_file" ]]; then
        print_status "Uploading to S3 bucket: $S3_BUCKET"
        
        if command -v aws &> /dev/null; then
            aws s3 cp "$backup_file" "s3://$S3_BUCKET/video-summary-backups/" 2>/dev/null || {
                print_warning "Failed to upload to S3"
                return 1
            }
            print_success "Backup uploaded to S3"
        else
            print_warning "AWS CLI not found, skipping S3 upload"
        fi
    fi
}

# Clean old backups
cleanup_old_backups() {
    print_status "Cleaning up backups older than $RETENTION_DAYS days..."
    
    # Clean local backups
    find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true
    
    # Clean remote backups if configured
    if [[ -n "$REMOTE_BACKUP" ]]; then
        ssh "${REMOTE_BACKUP%:*}" "find ${REMOTE_BACKUP#*:} -type f -name '*.tar.gz' -mtime +$RETENTION_DAYS -delete" 2>/dev/null || print_warning "Failed to clean remote backups"
    fi
    
    # Clean S3 backups if configured
    if [[ -n "$S3_BUCKET" ]] && command -v aws &> /dev/null; then
        aws s3 ls "s3://$S3_BUCKET/video-summary-backups/" --recursive | awk '{print $4}' | while read -r file; do
            file_date=$(echo "$file" | grep -o '[0-9]\{8\}_[0-9]\{6\}' | head -1)
            if [[ -n "$file_date" ]]; then
                file_timestamp=$(date -d "${file_date:0:8} ${file_date:9:2}:${file_date:11:2}:${file_date:13:2}" +%s 2>/dev/null || echo 0)
                cutoff_timestamp=$(date -d "$RETENTION_DAYS days ago" +%s)
                if [[ $file_timestamp -lt $cutoff_timestamp ]]; then
                    aws s3 rm "s3://$S3_BUCKET/$file" 2>/dev/null || true
                fi
            fi
        done 2>/dev/null || print_warning "Failed to clean S3 backups"
    fi
    
    print_success "Old backups cleaned up"
}

# Generate backup report
generate_report() {
    local backup_files=("$@")
    local report_file="$BACKUP_DIR/backup_report_$(get_timestamp).txt"
    
    cat > "$report_file" << EOF
===========================================
Video Summary API Backup Report
===========================================
Date: $(date)
Hostname: $(hostname)
Backup Directory: $BACKUP_DIR
Retention Days: $RETENTION_DAYS
Compression: $COMPRESS
Remote Backup: ${REMOTE_BACKUP:-"None"}
S3 Bucket: ${S3_BUCKET:-"None"}

===========================================
Backup Files Created:
===========================================
EOF
    
    for file in "${backup_files[@]}"; do
        if [[ -e "$file" ]]; then
            echo "✅ $(basename "$file") ($(du -h "$file" | cut -f1))" >> "$report_file"
        else
            echo "❌ $(basename "$file") (Failed)" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

===========================================
System Information:
===========================================
Disk Usage:
$(df -h / | tail -1)

Memory Usage:
$(free -h | grep Mem)

Docker Status:
$(docker compose -f docker-compose.prod.yml ps 2>/dev/null || echo "Docker services not running")

===========================================
Recent Backup History:
===========================================
$(ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5 || echo "No previous backups found")
EOF
    
    print_success "Backup report generated: $report_file"
    
    # Display summary
    echo
    print_status "=== BACKUP SUMMARY ==="
    cat "$report_file" | grep -A 20 "Backup Files Created:"
}

# Main backup function
main() {
    echo "💾 Video Summary API Backup Script"
    echo "=================================="
    echo
    echo "Backup Directory: $BACKUP_DIR"
    echo "Retention: $RETENTION_DAYS days"
    echo "Compression: $COMPRESS"
    echo "Remote: ${REMOTE_BACKUP:-"None"}"
    echo "S3 Bucket: ${S3_BUCKET:-"None"}"
    echo
    
    check_permissions
    setup_backup_dir
    
    local backup_files=()
    
    # Create backups
    print_status "Starting backup process..."
    
    # Application data backup
    local app_backup=$(backup_application_data)
    app_backup=$(compress_backup "$app_backup")
    backup_files+=("$app_backup")
    
    # SSL certificates backup
    local ssl_backup=$(backup_ssl_certificates)
    if [[ -n "$ssl_backup" ]]; then
        ssl_backup=$(compress_backup "$ssl_backup")
        backup_files+=("$ssl_backup")
    fi
    
    # Docker images backup
    local docker_backup=$(backup_docker_images)
    docker_backup=$(compress_backup "$docker_backup")
    backup_files+=("$docker_backup")
    
    # Database backup (if applicable)
    local db_backup=$(backup_database)
    if [[ -n "$db_backup" ]]; then
        db_backup=$(compress_backup "$db_backup")
        backup_files+=("$db_backup")
    fi
    
    # Upload backups
    for backup_file in "${backup_files[@]}"; do
        upload_to_remote "$backup_file"
        upload_to_s3 "$backup_file"
    done
    
    # Cleanup and report
    cleanup_old_backups
    generate_report "${backup_files[@]}"
    
    print_success "🎉 Backup process completed successfully!"
}

# Run main function
main "$@" 