#!/bin/bash

# Video Summary API - VM Testing Script
# This script sets up and tests the application in a VM environment

set -e

echo "🎬 Video Summary API - VM Testing Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if Docker and Docker Compose are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

# Check if .env file exists
check_env_file() {
    print_status "Checking environment file..."
    
    if [ ! -f "backend/.env" ]; then
        print_warning "backend/.env file not found"
        print_status "Creating sample .env file..."
        
        cat > backend/.env << 'EOF'
# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4

# YouTube API
YOUTUBE_API_KEY=your_youtube_api_key_here

# Azure Storage Configuration
AZURE_STORAGE_AUTH_TYPE=servicePrincipal
AZURE_STORAGE_ACCOUNT_NAME=your_storage_account
AZURE_STORAGE_CONTAINER_NAME=summary
AZURE_STORAGE_ACCOUNT_KEY=your_storage_key
AZURE_TENANT_ID=your_tenant_id
AZURE_CLIENT_ID=your_client_id
AZURE_CLIENT_SECRET=your_client_secret

# Application Configuration
MAX_FILE_SIZE=100MB
MAX_LOCAL_FILESIZE=104857600
MAX_LOCAL_FILESIZE_MB=100
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Environment
NODE_ENV=production
EOF
        
        print_warning "Please update backend/.env with your actual API keys and configuration"
        print_warning "The application will not work properly without valid API keys"
    else
        print_success "Environment file found"
    fi
}

# Build and start services
start_services() {
    print_status "Building and starting services..."
    
    # Stop any existing containers
    docker compose down
    
    # Build and start
    docker compose up --build -d
    
    print_success "Services started"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for backend
    timeout=60
    count=0
    while [ $count -lt $timeout ]; do
        if curl -s http://localhost:5050/health > /dev/null 2>&1; then
            print_success "Backend is ready"
            break
        fi
        sleep 2
        count=$((count + 2))
    done
    
    if [ $count -ge $timeout ]; then
        print_error "Backend failed to start within $timeout seconds"
        return 1
    fi
    
    # Wait for nginx
    count=0
    while [ $count -lt $timeout ]; do
        if curl -s http://localhost/health > /dev/null 2>&1; then
            print_success "Nginx is ready"
            break
        fi
        sleep 2
        count=$((count + 2))
    done
    
    if [ $count -ge $timeout ]; then
        print_error "Nginx failed to start within $timeout seconds"
        return 1
    fi
}

# Run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    # Test nginx health
    if curl -s http://localhost/health | grep -q "healthy"; then
        print_success "✅ Nginx health check passed"
    else
        print_error "❌ Nginx health check failed"
        return 1
    fi
    
    # Test backend health
    if curl -s http://localhost/api/health > /dev/null 2>&1; then
        print_success "✅ Backend health check passed"
    else
        print_error "❌ Backend health check failed"
        return 1
    fi
    
    # Test main page
    if curl -s http://localhost/ | grep -q "Video Summary API"; then
        print_success "✅ Main page accessible"
    else
        print_error "❌ Main page not accessible"
        return 1
    fi
}

# Show service status
show_status() {
    print_status "Service Status:"
    docker compose ps
    
    echo ""
    print_status "Application URLs:"
    echo "🌐 Main Interface: http://localhost"
    echo "🔧 Backend API: http://localhost/api"
    echo "❤️ Health Check: http://localhost/health"
    echo "📊 Backend Direct: http://localhost:5050"
    
    echo ""
    print_status "Test Commands:"
    echo "curl http://localhost/health"
    echo "curl http://localhost/api/health"
    echo ""
}

# Show logs
show_logs() {
    if [ "$1" = "logs" ]; then
        print_status "Showing service logs (press Ctrl+C to exit):"
        docker compose logs -f
    fi
}

# Cleanup
cleanup() {
    if [ "$1" = "down" ]; then
        print_status "Stopping services..."
        docker compose down
        print_success "Services stopped"
    fi
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            check_dependencies
            check_env_file
            start_services
            wait_for_services
            run_health_checks
            show_status
            ;;
        "logs")
            show_logs "logs"
            ;;
        "down")
            cleanup "down"
            ;;
        "status")
            docker compose ps
            show_status
            ;;
        "test")
            run_health_checks
            ;;
        *)
            echo "Usage: $0 {start|logs|down|status|test}"
            echo ""
            echo "Commands:"
            echo "  start  - Build and start all services (default)"
            echo "  logs   - Show service logs"
            echo "  down   - Stop all services"
            echo "  status - Show service status"
            echo "  test   - Run health checks"
            exit 1
            ;;
    esac
}

main "$@" 