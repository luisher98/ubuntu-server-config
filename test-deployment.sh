#!/bin/bash

# Exit on error
set -e

# Function to check if a service is running
check_service() {
    local service=$1
    if docker compose ps | grep -q "$service.*running"; then
        echo "✅ $service is running"
        return 0
    else
        echo "❌ $service is not running"
        return 1
    fi
}

# Function to check if a port is listening
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        echo "✅ Port $port is listening"
        return 0
    else
        echo "❌ Port $port is not listening"
        return 1
    fi
}

# Function to test HTTP endpoint with timeout
test_endpoint() {
    local url=$1
    local expected_status=$2
    local timeout=${3:-10}
    local response=$(curl -s -w "%{http_code}" --max-time $timeout $url)
    local status_code=${response: -3}
    local body=${response:0:${#response}-3}

    if [ "$status_code" = "$expected_status" ]; then
        echo "✅ $url returned $status_code"
        return 0
    else
        echo "❌ $url returned $status_code (expected $expected_status)"
        return 1
    fi
}

# Function to check rate limiting
check_rate_limit() {
    local url=$1
    local requests=20
    local success=0
    local failed=0

    echo "Testing rate limiting for $url..."
    for i in $(seq 1 $requests); do
        if curl -s -w "%{http_code}" --max-time 5 $url | grep -q "200"; then
            ((success++))
        else
            ((failed++))
        fi
        sleep 0.1
    done

    if [ $failed -gt 0 ]; then
        echo "✅ Rate limiting is working ($failed requests were rate limited)"
        return 0
    else
        echo "❌ Rate limiting might not be working (all requests succeeded)"
        return 1
    fi
}

# Function to check logs
check_logs() {
    local service=$1
    local log_file=$2
    if docker compose exec $service test -f $log_file; then
        echo "✅ Log file exists: $log_file"
        return 0
    else
        echo "❌ Log file missing: $log_file"
        return 1
    fi
}

echo "🔍 Starting deployment tests..."

# Check if all services are running
echo -e "\n📦 Checking services..."
check_service "backend" || exit 1
check_service "frontend" || exit 1
check_service "nginx" || exit 1

# Check if nginx is listening on port 80
echo -e "\n🔌 Checking ports..."
check_port "80" || exit 1

# Check log files
echo -e "\n📝 Checking log files..."
check_logs "nginx" "/var/log/nginx/access.log" || exit 1
check_logs "nginx" "/var/log/nginx/error.log" || exit 1
check_logs "nginx" "/var/log/nginx/frontend_access.log" || exit 1
check_logs "nginx" "/var/log/nginx/frontend_error.log" || exit 1

# Test endpoints with timeouts
echo -e "\n🌐 Testing endpoints..."
test_endpoint "http://localhost" "200" 5 || exit 1
test_endpoint "http://localhost/api/health" "200" 5 || exit 1

# Test rate limiting
echo -e "\n⚡ Testing rate limiting..."
check_rate_limit "http://localhost/api/health" || exit 1

echo -e "\n✨ All tests passed successfully!" 