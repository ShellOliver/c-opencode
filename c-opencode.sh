#!/bin/bash
#
# c-opencode.sh - Local wrapper for OpenCode server/client architecture
# Usage: c-opencode.sh <command> [args]
#

set -e

# ============================================================================
# Configuration
# ============================================================================

SERVER_HOST="0.0.0.0"
SERVER_PORT=4096
CONTAINER_LABEL="opencode.managed=true"
REMAINING_ARGS=()

# Resolve the real script path (handles symlinks)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# ============================================================================
# Helper Functions
# ============================================================================

get_container_hash() {
    local project_path
    project_path=$(cd "$PWD" && pwd)
    echo "$project_path" | md5sum | cut -c1-16
}

get_container_name() {
    echo "opencode-$(get_container_hash)"
}

get_container_by_path() {
    local hash=$(get_container_hash)
    echo "opencode-${hash}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running"
        exit 1
    fi
}

ensure_docker_image() {
    if docker image inspect opencode:latest &> /dev/null; then
        return 0
    fi
    
    echo "Building Docker image from Dockerfile..."
    local dockerfile_path="${SCRIPT_DIR}/Dockerfile"
    
    if [ ! -f "$dockerfile_path" ]; then
        echo "Error: Dockerfile not found at $dockerfile_path"
        exit 1
    fi
    
    docker build -t opencode:latest -f "$dockerfile_path" "$SCRIPT_DIR"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to build Docker image"
        exit 1
    fi
    
    echo "Docker image built successfully"
}

wait_for_container_ready() {
    local container_name=$1
    local max_attempts=30
    local attempt=0
    
    echo "Waiting for container to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if [ $attempt -gt 0 ]; then
            sleep 1
        fi
        
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "")
        if [ "$status" = "running" ]; then
            local port=$(get_container_port "$container_name")
            if [ -n "$port" ]; then
                echo "Container is ready"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "Error: Container failed to become ready within timeout"
    return 1
}

get_container_port() {
    local container_name=$1
    docker port "$container_name" 4096 2>/dev/null | cut -d: -f2 || echo ""
}

get_container_by_label() {
    docker ps --filter "label=${CONTAINER_LABEL}" --format "{{.Names}}" 2>/dev/null || echo ""
}

get_container_by_path_label() {
    local path=$1
    docker ps --filter "label=${CONTAINER_LABEL}" --filter "label=opencode.path=${path}" --format "{{.Names}}" 2>/dev/null || echo ""
}

check_server() {
    local host=$1
    local port=$2
    if timeout 2 bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
        return 0
    fi
    return 1
}

# ============================================================================
# Command Functions
# ============================================================================

cmd_web() {
    check_docker
    ensure_docker_image
    
    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    
    if [ -z "$port" ]; then
        echo "Server not running. Starting..."
        docker run -d \
            --name "$container_name" \
            --label "${CONTAINER_LABEL}" \
            -p 127.0.0.1::${SERVER_PORT} \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "$(pwd):/workspace/project:rw" \
            -w /workspace/project \
            opencode:latest
        
        wait_for_container_ready "$container_name"
        port=$(get_container_port "$container_name")
    fi
    
    echo "http://127.0.0.1:${port}"
}

cmd_help() {
    echo "OpenCode Local Wrapper"
    echo ""
    echo "Usage: c-opencode [command] [args]"
    echo ""
    echo "Commands:"
    echo "  (no args)    Start server and attach to OpenCode TUI"
    echo "  web          Show server URL"
    echo "  help         Show this help message"
    echo ""
    echo "Pass-through:"
    echo "  Any other arguments are passed to opencode with --attach flag."
    echo "  Examples:"
    echo "    c-opencode run 'add feature'"
    echo "    c-opencode session list"
    echo "    c-opencode stats"
    echo "    c-opencode models"
    echo ""
    echo "Container Management (use Docker directly):"
    echo "  docker ps                          # List running containers"
    echo "  docker logs <container>            # Show logs"
    echo "  docker stop <container>            # Stop container"
    echo "  docker rm <container>              # Remove container"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local command="${1:-}"
    
    case "$command" in
        "")
            # Default: start server if needed and attach TUI
            check_docker
            ensure_docker_image
            
            local container_name=$(get_container_name)
            local port=$(get_container_port "$container_name")
            
            if [ -z "$port" ]; then
                echo "Server not running. Starting..."
                docker run -d \
                    --name "$container_name" \
                    --label "${CONTAINER_LABEL}" \
                    -p 127.0.0.1::${SERVER_PORT} \
                    -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
                    -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
                    -v "${HOME}/.local/state:/home/node/.local/state:rw" \
                    -v "$(pwd):/workspace/project:rw" \
                    -w /workspace/project \
                    opencode:latest
                
                wait_for_container_ready "$container_name"
                port=$(get_container_port "$container_name")
            fi
            
            local server_url="http://127.0.0.1:${port}"
            opencode attach "$server_url" --dir /workspace/project
            ;;
        web)
            cmd_web
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            # Pass through to opencode with --attach flag
            check_docker
            local container_name=$(get_container_name)
            local port=$(get_container_port "$container_name")
            
            if [ -z "$port" ]; then
                echo "Error: Server not running. Run 'c-opencode' to start."
                exit 1
            fi
            
            local server_url="http://127.0.0.1:${port}"
            opencode "$@" --attach "$server_url" --dir /workspace/project
            ;;
    esac
}

if [ "${BATS_TEST:-false}" != "true" ]; then
    main "$@"
fi
