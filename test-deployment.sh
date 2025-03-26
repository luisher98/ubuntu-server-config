#!/bin/bash

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

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local expected_status=$2
    local response=$(curl -s -w "%{http_code}" $url)
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

echo "🔍 Starting deployment tests..."

# Check if all services are running
echo -e "\n📦 Checking services..."
check_service "backend" || exit 1
check_service "frontend" || exit 1
check_service "nginx" || exit 1

# Check if nginx is listening on port 80
echo -e "\n🔌 Checking ports..."
check_port "80" || exit 1

# Test endpoints
echo -e "\n🌐 Testing endpoints..."
test_endpoint "http://localhost" "200" || exit 1
test_endpoint "http://localhost/api/health" "200" || exit 1

echo -e "\n✨ All tests passed successfully!" 