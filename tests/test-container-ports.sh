#!/bin/bash
# Test script for container.yaml port configuration
# This verifies that ports exposed via .opencode/container.yaml are accessible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/test-project"

echo "=== Container.yaml Port Configuration Test ==="
echo ""

# Navigate to test project
cd "$PROJECT_DIR"
echo "Working directory: $(pwd)"
echo ""

# Function to check if port is accessible
check_port() {
    local port=$1
    local max_attempts=30
    local attempt=0

    echo "Testing port ${port}..."

    while [ $attempt -lt $max_attempts ]; do
        # Use curl instead of bash tcp test for more reliability
        if curl -s --connect-timeout 2 http://127.0.0.1:${port}/ >/dev/null 2>&1; then
            echo "✓ Port ${port} is accessible!"
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 1
    done

    echo "✗ Port ${port} is not accessible"
    return 1
}

# Function to check if container is running
check_container_running() {
    local container_name=$1
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "")

    if [ "$status" = "running" ]; then
        return 0
    fi
    return 1
}

# Get container name
CONTAINER_HASH=$(cd "$PROJECT_DIR" && pwd | md5sum | cut -c1-16)
CONTAINER_NAME="opencode-${CONTAINER_HASH}"

echo "Container name: $CONTAINER_NAME"
echo ""

# Check if container already exists
if docker ps -a --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q "${CONTAINER_NAME}"; then
    echo "Container already exists. Stopping and removing..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    echo ""
fi

# Start container with c-opencode web
echo "Starting container with c-opencode web..."
echo ""

cd "$PROJECT_DIR"
OPENCODE_OUTPUT="$("${SCRIPT_DIR}/../c-opencode.sh" web 2>&1)"
SERVER_URL=$(echo "$OPENCODE_OUTPUT" | grep -o 'http://[^ ]*')

echo "Server URL: $SERVER_URL"
echo ""

# Wait for container to be ready
echo "Waiting for container to be ready..."
echo ""

max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if check_container_running "${CONTAINER_NAME}"; then
        # Wait a bit more for server inside to start
        sleep 3
        break
    fi

    attempt=$((attempt + 1))
    if [ $attempt -gt 0 ]; then
        echo "Waiting... ($attempt/$max_attempts)"
    fi
    sleep 1
done

if ! check_container_running "${CONTAINER_NAME}"; then
    echo "✗ Container failed to start"
    echo "Container logs:"
    docker logs "${CONTAINER_NAME}"
    exit 1
fi

echo "✓ Container is running"
echo ""

# Test if custom ports are accessible
echo "=== Testing Port Accessibility ==="
echo ""

if check_port 3011; then
    echo ""
    echo "=== Verifying Server Content ==="
    echo ""

    # Try to fetch content from the server
    HTTP_RESPONSE=$(curl -s http://127.0.0.1:3011/ 2>/dev/null || echo "")

    if [ -n "$HTTP_RESPONSE" ]; then
        echo "✓ Successfully retrieved content from server:"
        echo ""
        echo "$HTTP_RESPONSE"
        echo ""
        echo "✓ Test PASSED: Port 3011 is correctly exposed and accessible"
    else
        echo "✗ Test FAILED: Could not retrieve content from server"
        exit 1
    fi
else
    echo "✗ Test FAILED: Port 3011 is not accessible"
    exit 1
fi

# Cleanup
echo ""
echo "=== Cleanup ==="
echo ""

echo "Stopping container..."
docker stop "${CONTAINER_NAME}" 2>/dev/null
docker rm "${CONTAINER_NAME}" 2>/dev/null

echo "✓ Test completed successfully!"
