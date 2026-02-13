#!/bin/bash
#
# c-opencode.sh - Local wrapper for OpenCode server/client architecture
# Usage: c-opencode.sh <command> [args]
#

set -e

# ============================================================================
# Configuration
# ============================================================================

SERVER_HOST="127.0.0.1"
SERVER_PORT=4096
CONTAINER_LABEL="opencode.managed=true"

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
    local port=$1
    if timeout 2 bash -c "echo > /dev/tcp/${SERVER_HOST}/${port}" 2>/dev/null; then
        return 0
    fi
    return 1
}

cleanup_stopped_containers() {
    echo "Cleaning up stopped OpenCode containers..."
    local containers=$(docker ps -a --filter "label=${CONTAINER_LABEL}" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$containers" ]; then
        echo "  No stopped OpenCode containers found"
        return 0
    fi
    
    for container in $containers; do
        local state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "")
        if [ "$state" = "exited" ]; then
            echo "  Removing stopped container: $container"
            docker rm "$container" > /dev/null
        fi
    done
}

# ============================================================================
# Command Functions
# ============================================================================

cmd_start() {
    check_docker
    
    local container_name=$(get_container_name)
    local current_dir=$(pwd)
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "")
        if [ "$status" = "running" ]; then
            echo "Server is already running"
            local port=$(get_container_port "$container_name")
            echo "Server URL: http://${SERVER_HOST}:${port}"
            return 0
        else
            echo "Starting existing container..."
            docker start "$container_name" > /dev/null
        fi
    else
        echo "Starting new container..."
        docker run -d \
            --name "$container_name" \
            --label "${CONTAINER_LABEL}" \
            --label "opencode.path=${current_dir}" \
            -p "${SERVER_HOST}::${SERVER_PORT}" \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "${current_dir}:/workspace:rw" \
            -e "NODE_ENV=production" \
            opencode:latest
    fi
    
    if ! wait_for_container_ready "$container_name"; then
        echo "Error: Failed to start server"
        return 1
    fi
    
    local port=$(get_container_port "$container_name")
    echo "✓ Server started on http://${SERVER_HOST}:${port}"
}

cmd_stop() {
    check_docker
    
    local container_name=$(get_container_name)
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "Container $container_name is not running"
        return 0
    fi
    
    echo "Stopping container $container_name..."
    docker stop "$container_name" > /dev/null
    echo "✓ Server stopped"
}

cmd_restart() {
    cmd_stop
    cmd_start
}

cmd_status() {
    check_docker
    
    local container_name=$(get_container_name)
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "✗ No server found for this project"
        echo ""
        echo "To start the server:"
        echo "  c-opencode.sh start"
        return 1
    fi
    
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "")
    local port=$(get_container_port "$container_name")
    local server_url="http://${SERVER_HOST}:${port}"
    
    if [ "$status" != "running" ]; then
        echo "⚠ Container exists but is not running (status: $status)"
        echo "  Try: c-opencode.sh start"
        return 1
    fi
    
    if [ -z "$port" ]; then
        echo "⚠ Container is running but port is not assigned yet"
        return 1
    fi
    
    if check_server "$port"; then
        echo "✓ Server is running on ${server_url}"
        echo ""
        echo "Server Info:"
        echo "  Server URL: ${server_url}"
        return 0
    else
        echo "⚠ Container running but server not responding on port $port"
        echo "  Try: c-opencode.sh restart"
        return 1
    fi
}

cmd_logs() {
    check_docker
    
    local container_name=$(get_container_name)
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "Container $container_name is not running"
        return 1
    fi
    
    docker logs -f "$container_name"
}

cmd_run() {
    check_docker
    
    local prompt="$@"
    if [ -z "$prompt" ]; then
        echo "Usage: c-opencode.sh run <prompt>"
        exit 1
    fi
    
    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    
    if [ -z "$port" ]; then
        echo "Server not running. Starting..."
        cmd_start
        port=$(get_container_port "$container_name")
    elif ! check_server "$port"; then
        echo "Server not responding. Restarting..."
        cmd_restart
        port=$(get_container_port "$container_name")
    fi
    
    echo "Running: $prompt"
    node "${SCRIPT_DIR}/scripts/opencode-run.js" "http://${SERVER_HOST}:${port}" "$prompt"
}

cmd_list_sessions() {
    check_docker
    
    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    
    if [ -z "$port" ]; then
        echo "Server not running. Starting..."
        cmd_start
        port=$(get_container_port "$container_name")
    elif ! check_server "$port"; then
        echo "Server not responding. Restarting..."
        cmd_restart
        port=$(get_container_port "$container_name")
    fi
    
    echo "Listing sessions..."
    node "${SCRIPT_DIR}/scripts/opencode-list-sessions.js" "http://${SERVER_HOST}:${port}"
}

cmd_list() {
    check_docker
    
    echo "OpenCode Servers:"
    echo ""
    
    local containers=$(docker ps -a --filter "label=${CONTAINER_LABEL}" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$containers" ]; then
        echo "  No OpenCode containers found"
        return 0
    fi
    
    for container in $containers; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        local port
        port=$(get_container_port "$container")
        [ -z "$port" ] && port="N/A"
        local path=$(docker inspect --format='{{index .Config.Labels "opencode.path"}}' "$container" 2>/dev/null || echo "N/A")
        
        printf "  %-30s %s (port: %s)\n" "$container" "[$status]" "$port"
        if [ "$path" != "N/A" ]; then
            printf "    Path: %s\n" "$path"
        fi
    done
}

cmd_clean() {
    check_docker
    cleanup_stopped_containers
}

cmd_help() {
    echo "OpenCode Local Wrapper"
    echo ""
    echo "Usage: c-opencode.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start              Start the OpenCode server"
    echo "  run <prompt>       Execute a prompt and get response"
    echo "  stop               Stop the OpenCode server"
    echo "  restart            Restart the OpenCode server"
    echo "  status             Check server health"
    echo "  logs               View container logs"
    echo "  list               List all OpenCode servers"
    echo "  list-sessions      List all active sessions"
    echo "  clean              Remove stopped containers"
    echo "  help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  c-opencode.sh start"
    echo "  c-opencode.sh run \"analyze this codebase\""
    echo "  c-opencode.sh status"
    echo "  c-opencode.sh list"
    echo "  c-opencode.sh list-sessions"
    echo "  c-opencode.sh clean"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start)
            cmd_start "$@"
            ;;
        run)
            cmd_run "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status|health|ping)
            cmd_status "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        list|list-servers)
            cmd_list "$@"
            ;;
        list-sessions|ls)
            cmd_list_sessions "$@"
            ;;
        clean|cleanup)
            cmd_clean "$@"
            ;;
        help|--help|-h)
            cmd_help "$@"
            ;;
        *)
            echo "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
