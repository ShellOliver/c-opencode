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
WORKTREE_DIR=".git/worktrees"

ADDITIONAL_PORTS=()
IS_PUBLIC=false
USE_WORKTREE=false
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

get_worktree_hash() {
    local project_path
    project_path=$(cd "$PWD" && pwd)
    echo "$project_path" | md5sum | cut -c1-8
}

get_worktree_path() {
    local hash=$(get_worktree_hash)
    echo "${WORKTREE_DIR}/opencode-${hash}"
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
    local host=$1
    local port=$2
    if timeout 2 bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
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

parse_args() {
    ADDITIONAL_PORTS=()
    IS_PUBLIC=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--port)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: -p/--port requires a port number"
                    exit 1
                fi
                ADDITIONAL_PORTS+=("$2")
                shift 2
                ;;
            --public)
                IS_PUBLIC=true
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Unknown option: $1"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
}

parse_global_flags() {
    REMAINING_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktree)
                USE_WORKTREE=true
                shift
                ;;
            -*)
                REMAINING_ARGS+=("$1")
                shift
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

get_bind_host() {
    if [ "$IS_PUBLIC" = true ]; then
        echo "0.0.0.0"
    else
        echo "127.0.0.1"
    fi
}

build_docker_ports() {
    local bind_host=$(get_bind_host)
    local ports="-p ${bind_host}::${SERVER_PORT}"
    
    for port in "${ADDITIONAL_PORTS[@]}"; do
        ports="$ports -p ${bind_host}::${port}"
    done
    
    echo "$ports"
}

ensure_worktree() {
    local worktree_path=$(get_worktree_path)
    local current_dir=$(pwd)
    
    if [ -d "$worktree_path" ]; then
        return 0
    fi
    
    if [ ! -d "$WORKTREE_DIR" ]; then
        mkdir -p "$WORKTREE_DIR"
    fi
    
    if ! git worktree add "$worktree_path" --force 2>/dev/null; then
        echo "Warning: Failed to create worktree (not a git repo?). Using current directory."
        return 1
    fi
    
    for env_file in .env .env.local .env.development .env.production .env.*; do
        if [ -f "$env_file" ] && [ ! -f "$worktree_path/$env_file" ]; then
            cp "$env_file" "$worktree_path/" 2>/dev/null || true
        fi
    done
    
    return 0
}

# ============================================================================
# Command Functions
# ============================================================================

cmd_start() {
    check_docker
    
    local container_name=$(get_container_name)
    local current_dir=$(pwd)
    local workspace_dir="$current_dir"
    local ports=$(build_docker_ports)
    
    if [ "$USE_WORKTREE" = true ]; then
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            echo "Error: --worktree requires a git repository"
            exit 1
        fi
        local worktree_path=$(get_worktree_path)
        if ! ensure_worktree; then
            echo "Error: Failed to create worktree"
            exit 1
        fi
        workspace_dir="$worktree_path"
    fi
    
    local env_vars="-e NODE_ENV=production"
    
    if [ "$IS_PUBLIC" = true ]; then
        if [ -z "$OPENCODE_SERVER_PASSWORD" ]; then
            echo "Error: --public flag requires OPENCODE_SERVER_PASSWORD to be set"
            echo "       Set it with: export OPENCODE_SERVER_PASSWORD=your-password"
            exit 1
        fi
        env_vars="$env_vars -e OPENCODE_SERVER_PASSWORD=$OPENCODE_SERVER_PASSWORD"
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "")
        if [ "$status" = "running" ]; then
            local port=$(get_container_port "$container_name")
            echo "Server is already running"
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
            --label "opencode.worktree=${workspace_dir}" \
            --label "opencode.public=${IS_PUBLIC}" \
            $ports \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "${workspace_dir}:/workspace:rw" \
            $env_vars \
            opencode:latest
    fi
    
    if ! wait_for_container_ready "$container_name"; then
        echo "Error: Failed to start server"
        return 1
    fi
    
    local port=$(get_container_port "$container_name")
    local bind_host=$(get_bind_host)
    
    echo ""
    echo "============================================"
    echo "  OpenCode Server Started"
    echo "============================================"
    echo ""
    echo "  Worktree: ${workspace_dir}"
    echo "  Server:   http://${bind_host}:${port}"
    echo ""
    echo "  To open in browser:"
    echo "    open http://${bind_host}:${port}"
    echo ""
    echo "  To attach a console:"
    echo "    c-opencode attach"
    echo ""
    echo "  To stop and remove:"
    echo "    c-opencode clean"
    echo ""
    echo "============================================"
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
        echo "  c-opencode start"
        return 1
    fi
    
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "")
    local port=$(get_container_port "$container_name")
    local is_public=$(docker inspect --format='{{index .Config.Labels "opencode.public"}}' "$container_name" 2>/dev/null || echo "false")
    local server_host="127.0.0.1"
    if [ "$is_public" = "true" ]; then
        server_host="0.0.0.0"
    fi
    local server_url="http://${server_host}:${port}"
    
    if [ "$status" != "running" ]; then
        echo "⚠ Container exists but is not running (status: $status)"
        echo "  Try: c-opencode start"
        return 1
    fi
    
    if [ -z "$port" ]; then
        echo "⚠ Container is running but port is not assigned yet"
        return 1
    fi
    
    if check_server "$server_host" "$port"; then
        echo "✓ Server is running on ${server_url}"
        echo ""
        echo "Server Info:"
        echo "  Server URL: ${server_url}"
        return 0
    else
        echo "⚠ Container running but server not responding on port $port"
        echo "  Try: c-opencode restart"
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

cmd_attach() {
    check_docker
    
    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    
    if [ -z "$port" ]; then
        echo "Server not running. Starting..."
        cmd_start
        port=$(get_container_port "$container_name")
    fi
    
    local is_public=$(docker inspect --format='{{index .Config.Labels "opencode.public"}}' "$container_name" 2>/dev/null || echo "false")
    local server_host="127.0.0.1"
    if [ "$is_public" = "true" ]; then
        server_host="0.0.0.0"
    fi
    
    if ! check_server "$server_host" "$port"; then
        echo "Server not responding. Restarting..."
        cmd_restart
        port=$(get_container_port "$container_name")
    fi
    
    local server_url="http://${server_host}:${port}"
    echo "Attaching to OpenCode server..."
    opencode attach "$server_url"
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
    fi
    
    local is_public=$(docker inspect --format='{{index .Config.Labels "opencode.public"}}' "$container_name" 2>/dev/null || echo "false")
    local server_host="127.0.0.1"
    if [ "$is_public" = "true" ]; then
        server_host="0.0.0.0"
    fi
    
    if ! check_server "$server_host" "$port"; then
        echo "Server not responding. Restarting..."
        cmd_restart
        port=$(get_container_port "$container_name")
    fi
    
    echo "Running: $prompt"
    node "${SCRIPT_DIR}/scripts/opencode-run.js" "http://${server_host}:${port}" "$prompt"
}

cmd_list_sessions() {
    check_docker
    
    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    
    if [ -z "$port" ]; then
        echo "Server not running. Starting..."
        cmd_start
        port=$(get_container_port "$container_name")
    fi
    
    local is_public=$(docker inspect --format='{{index .Config.Labels "opencode.public"}}' "$container_name" 2>/dev/null || echo "false")
    local server_host="127.0.0.1"
    if [ "$is_public" = "true" ]; then
        server_host="0.0.0.0"
    fi
    
    if ! check_server "$server_host" "$port"; then
        echo "Server not responding. Restarting..."
        cmd_restart
        port=$(get_container_port "$container_name")
    fi
    
    echo "Listing sessions..."
    node "${SCRIPT_DIR}/scripts/opencode-list-sessions.js" "http://${server_host}:${port}"
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
        local is_public=$(docker inspect --format='{{index .Config.Labels "opencode.public"}}' "$container" 2>/dev/null || echo "false")
        
        local host="127.0.0.1"
        if [ "$is_public" = "true" ]; then
            host="0.0.0.0"
        fi
        
        printf "  %-30s %s (port: %s)\n" "$container" "[$status]" "$port"
        if [ "$path" != "N/A" ]; then
            printf "    Path: %s\n" "$path"
        fi
        printf "    URL:  http://%s:%s\n" "$host" "$port"
    done
}

cmd_worktree() {
    local worktree_path=$(get_worktree_path)
    local worktree_hash=$(get_worktree_hash)
    local current_dir=$(pwd)
    
    if [ -d "$worktree_path" ]; then
        echo "Worktree already exists at: $worktree_path"
        echo ""
        echo "To work in the isolated environment:"
        echo "  cd $worktree_path"
        echo "  c-opencode start"
        return 0
    fi
    
    echo "Creating isolated worktree..."
    echo "  Source: $current_dir"
    echo "  Target: $worktree_path"
    
    mkdir -p "$WORKTREE_DIR"
    
    if ! git worktree add "$worktree_path" --force 2>/dev/null; then
        echo "Error: Failed to create worktree. Are you in a git repository?"
        exit 1
    fi
    
    echo ""
    echo "Copying environment files..."
    
    for env_file in .env .env.local .env.development .env.production .env.*; do
        if [ -f "$env_file" ]; then
            if [ -f "$worktree_path/$env_file" ]; then
                echo "  Skipping $env_file (already exists in worktree)"
            else
                cp "$env_file" "$worktree_path/"
                echo "  Copied $env_file"
            fi
        fi
    done
    
    echo ""
    echo "============================================"
    echo "  Worktree Created"
    echo "============================================"
    echo ""
    echo "  Worktree: $worktree_path"
    echo ""
    echo "  To start OpenCode in this isolated environment:"
    echo "    cd $worktree_path"
    echo "    c-opencode start"
    echo ""
    echo "  To return to original directory:"
    echo "    cd $current_dir"
    echo ""
    echo "  To remove the worktree:"
    echo "    c-opencode worktree remove"
    echo ""
    echo "============================================"
}

cmd_worktree_remove() {
    local worktree_path=$(get_worktree_path)
    
    if [ ! -d "$worktree_path" ]; then
        echo "No worktree found at: $worktree_path"
        return 0
    fi
    
    local container_name=$(get_container_name)
    
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "Stopping container $container_name..."
        docker stop "$container_name" > /dev/null 2>&1 || true
    fi
    
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "Removing container $container_name..."
        docker rm "$container_name" > /dev/null 2>&1 || true
    fi
    
    echo "Removing worktree at $worktree_path..."
    if ! git worktree remove "$worktree_path" --force 2>/dev/null; then
        echo "Warning: Failed to remove worktree cleanly, forcing..."
        rm -rf "$worktree_path"
    fi
    
    echo "Pruning stale worktree references..."
    git worktree prune 2>/dev/null || true
    
    echo ""
    echo "✓ Worktree removed"
}

cmd_clean() {
    check_docker
    
    local clean_all=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                clean_all=true
                shift
                ;;
            -*)
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    if [ "$clean_all" = true ]; then
        echo "Cleaning all OpenCode containers and worktrees..."
        echo ""
        
        local containers=$(docker ps -a --filter "label=${CONTAINER_LABEL}" --format "{{.Names}}" 2>/dev/null)
        
        if [ -n "$containers" ]; then
            for container in $containers; do
                local worktree_path=$(docker inspect --format='{{index .Config.Labels "opencode.worktree"}}' "$container" 2>/dev/null || echo "")
                
                echo "Removing container: $container"
                docker stop "$container" > /dev/null 2>&1 || true
                docker rm "$container" > /dev/null 2>&1 || true
                
                if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
                    echo "  Removing worktree: $worktree_path"
                    if ! git -C "$(git rev-parse --show-toplevel 2>/dev/null || echo ".")" worktree remove "$worktree_path" --force 2>/dev/null; then
                        rm -rf "$worktree_path" 2>/dev/null || true
                    fi
                fi
            done
        else
            echo "  No containers found"
        fi
        
        echo ""
        echo "Cleaning orphaned worktrees..."
        if [ -d ".git/worktrees" ]; then
            for worktree in .git/worktrees/opencode-*; do
                if [ -d "$worktree" ]; then
                    echo "  Removing orphaned worktree: $worktree"
                    rm -rf "$worktree" 2>/dev/null || true
                fi
            done
            git worktree prune 2>/dev/null || true
        else
            echo "  No orphaned worktrees found"
        fi
        
        echo ""
        echo "✓ Cleanup complete"
        return 0
    fi
    
    local container_name=$(get_container_name)
    local worktree_path=$(get_worktree_path)
    local cleaned=false
    
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "Stopping and removing container $container_name..."
        docker stop "$container_name" > /dev/null 2>&1 || true
        docker rm "$container_name" > /dev/null 2>&1 || true
        cleaned=true
    fi
    
    cleanup_stopped_containers
    
    if [ -d "$worktree_path" ]; then
        cmd_worktree_remove
        cleaned=true
    fi
    
    if [ "$cleaned" = false ]; then
        echo "Nothing to clean"
    else
        echo ""
        echo "✓ Cleanup complete"
    fi
}

cmd_help() {
    echo "OpenCode Local Wrapper"
    echo ""
    echo "Usage: c-opencode.sh [global-options] <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [options]       Start the OpenCode server"
    echo "  run <prompt>          Execute a prompt and get response"
    echo "  stop                  Stop the OpenCode server"
    echo "  restart               Restart the OpenCode server"
    echo "  status                Check server health"
    echo "  logs                  View container logs"
    echo "  attach                Open OpenCode UI in browser"
    echo "  list                  List all OpenCode servers"
    echo "  list-sessions         List all active sessions"
    echo "  worktree [remove]     Create/manage isolated worktree"
    echo "  clean [--all]         Stop container and remove worktree"
    echo "  help                  Show this help message"
    echo ""
    echo "Global Options:"
    echo "  --worktree            Use git worktree for isolation (mounts worktree instead of current dir)"
    echo ""
    echo "Options:"
    echo "  -p, --port <port>     Expose additional container port"
    echo "  --public              Bind to 0.0.0.0 (requires OPENCODE_SERVER_PASSWORD)"
    echo "  --all                 Clean all projects (for clean command)"
    echo ""
    echo "Examples:"
    echo "  c-opencode                      # Start server (current dir mounted)"
    echo "  c-opencode --worktree           # Start with worktree isolation"
    echo "  c-opencode start                # Start the OpenCode server"
    echo "  c-opencode start --public       # Start with public access"
    echo "  c-opencode start -p 3000        # Expose port 3000"
    echo "  c-opencode start -p 3000 -p 8080"
    echo "  c-opencode run \"analyze this\""
    echo "  c-opencode attach               # Attach to server"
    echo "  c-opencode worktree             # Create isolated worktree"
    echo "  c-opencode worktree remove     # Remove worktree"
    echo "  c-opencode clean                # Stop and cleanup current project"
    echo "  c-opencode clean --all          # Stop and cleanup all projects"
}

# ============================================================================
# Main
# ============================================================================

main() {
    parse_global_flags "$@"
    
    local command="${REMAINING_ARGS[0]:-start}"
    local remaining=("${REMAINING_ARGS[@]:1}")
    
    case "$command" in
        start)
            parse_args "${remaining[@]}"
            SERVER_HOST=$(get_bind_host)
            cmd_start
            ;;
        run)
            cmd_run "${remaining[@]}"
            ;;
        stop)
            cmd_stop "${remaining[@]}"
            ;;
        restart)
            cmd_restart "${remaining[@]}"
            ;;
        status|health|ping)
            cmd_status "${remaining[@]}"
            ;;
        logs)
            cmd_logs "${remaining[@]}"
            ;;
        attach)
            cmd_attach "${remaining[@]}"
            ;;
        list|list-servers)
            cmd_list "${remaining[@]}"
            ;;
        list-sessions|ls)
            cmd_list_sessions "${remaining[@]}"
            ;;
        worktree)
            if [ "${remaining[0]:-}" = "remove" ]; then
                cmd_worktree_remove
            else
                cmd_worktree
            fi
            ;;
        clean|cleanup)
            cmd_clean "${remaining[@]}"
            ;;
        help|--help|-h)
            cmd_help "${remaining[@]}"
            ;;
        *)
            parse_args "$command" "${remaining[@]}"
            SERVER_HOST=$(get_bind_host)
            cmd_start
            ;;
    esac
}

main "$@"
