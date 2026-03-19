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

get_yq_binary() {
    local script_dir="${SCRIPT_DIR}"

    if [ -x "$HOME/.local/bin/yq" ]; then
        echo "$HOME/.local/bin/yq"
        return
    fi

    local arch
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        i386|i686) arch="386" ;;
        *) arch="amd64" ;;
    esac

    local bundled_yq="${script_dir}/bin/yq_${os}_${arch}"

    if [ -f "$bundled_yq" ]; then
        echo "$bundled_yq"
        return
    fi

    echo ""
}

has_yq() {
    local yq_bin
    yq_bin=$(get_yq_binary)
    [ -n "$yq_bin" ] && [ -x "$yq_bin" ]
}

get_container_ports() {
    local config_file=".opencode/container.yaml"

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    if ! has_yq; then
        echo "Warning: yq not found. Cannot parse container.yaml"
        echo "Please run install.sh to set up yq."
        return 0
    fi

    local yq_bin
    yq_bin=$(get_yq_binary)

    "$yq_bin" eval '.ports[]' "$config_file" 2>/dev/null
}

get_port_flags() {
    local ports=$1
    local flags=""

    if [ -n "$ports" ]; then
        while IFS= read -r port; do
            if [ -n "$port" ]; then
                flags="${flags} -p ${port}"
            fi
        done <<< "$ports"
    fi

    flags="${flags} -p 127.0.0.1::${SERVER_PORT}"

    echo "$flags"
}

sanitize_image_name() {
    local name=$1

    if [ -z "$name" ]; then
        echo "default"
        return
    fi

    local sanitized
    sanitized=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\{1,\}/-/g' | sed 's/^-\{1,\}//;s/-\{1,\}$//')

    if [ -z "$sanitized" ]; then
        echo "default"
    else
        echo "$sanitized"
    fi
}

has_custom_build_script() {
    [ -f ".opencode/c-opencode-image.sh" ]
}

get_custom_image_name() {
    local project_name
    project_name=$(basename "$(pwd)")
    local sanitized
    sanitized=$(sanitize_image_name "$project_name")
    echo "opencode-${sanitized}:latest"
}

build_custom_image() {
    local image_name=$1
    local tmp_dockerfile
    tmp_dockerfile=$(mktemp)

    trap 'rm -f "$tmp_dockerfile"' EXIT

    cat > "$tmp_dockerfile" <<EOF
FROM opencode:latest
LABEL opencode.custom-built=true
LABEL opencode.source-folder="$(basename "$(pwd)")"
COPY .opencode/c-opencode-image.sh /tmp/build-script.sh
USER node
RUN bash /tmp/build-script.sh

# Clean up build artifacts
RUN rm -f /tmp/build-script.sh

# Use CMD from base image
CMD ["opencode", "serve", "--mdns", "--port", "4096"]
EOF

    echo "Building custom image: $image_name"
    if ! docker build -t "$image_name" -f "$tmp_dockerfile" "$(pwd)"; then
        echo "Error: Failed to build custom image"
        docker image rm "$image_name" &> /dev/null || true
        exit 1
    fi

    echo "Custom image built successfully: $image_name"
}

ensure_custom_image() {
    if ! has_custom_build_script; then
        return 0
    fi

    local image_name
    image_name=$(get_custom_image_name)

    if docker image inspect "$image_name" &> /dev/null; then
        return 0
    fi

    build_custom_image "$image_name"
}

get_target_image() {
    if has_custom_build_script; then
        ensure_custom_image
        get_custom_image_name
    else
        echo "opencode:latest"
    fi
}

force_rebuild_image() {
    check_docker

    if ! has_custom_build_script; then
        echo "No custom build script found in .opencode/c-opencode-image.sh"
        exit 1
    fi

    local image_name
    image_name=$(get_custom_image_name)

    echo "Removing existing image: $image_name"
    docker image rm "$image_name" &> /dev/null || true

    build_custom_image "$image_name"
}

# ============================================================================
# Command Functions
# ============================================================================

cmd_web() {
    check_docker
    ensure_docker_image

    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    local target_image
    target_image=$(get_target_image)

    if [ -z "$port" ]; then
        echo "Server not running. Starting..."

        local custom_ports
        custom_ports=$(get_container_ports)

        local port_flags
        port_flags=$(get_port_flags "$custom_ports")

        if [ -n "$custom_ports" ]; then
            echo "Exposing additional ports: $custom_ports"
        fi

        docker run -d \
            --name "$container_name" \
            --label "${CONTAINER_LABEL}" \
            ${port_flags} \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "$(pwd):/workspace/project:rw" \
            -w /workspace/project \
            "$target_image"

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
    echo "  (no args)       Start server and attach to OpenCode TUI"
    echo "  web             Show server URL"
    echo "  help            Show this help message"
    echo "  --rebuild-image Force rebuild custom image if .opencode/c-opencode-image.sh exists"
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
    echo ""
    echo "Container Configuration:"
    echo "  Create .opencode/container.yaml to configure ports and options."
    echo "  Example:"
    echo "    ports:"
    echo "      - \"3000:3000\""
    echo "      - \"8080:8080\""
    echo ""
    echo "  See README.md for full documentation and examples."
    echo ""
    echo "Custom Build Scripts:"
    echo "  Create .opencode/c-opencode-image.sh to customize the container image."
    echo "  The script runs inside the container during build (e.g., npm install)."
    echo "  Image name: opencode-<foldername>:latest"
    echo "  Rebuild: c-opencode --rebuild-image"
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
            local target_image
            target_image=$(get_target_image)

            if [ -z "$port" ]; then
                echo "Server not running. Starting..."

                local custom_ports
                custom_ports=$(get_container_ports)

                local port_flags
                port_flags=$(get_port_flags "$custom_ports")

                if [ -n "$custom_ports" ]; then
                    echo "Exposing additional ports: $custom_ports"
                fi

                docker run -d \
                    --name "$container_name" \
                    --label "${CONTAINER_LABEL}" \
                    ${port_flags} \
                    -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
                    -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
                    -v "${HOME}/.local/state:/home/node/.local/state:rw" \
                    -v "$(pwd):/workspace/project:rw" \
                    -w /workspace/project \
                    "$target_image"

                wait_for_container_ready "$container_name"
                port=$(get_container_port "$container_name")
            fi

            local server_url="http://127.0.0.1:${port}"
            opencode attach "$server_url" --dir /workspace/project
            ;;
        --rebuild-image)
            force_rebuild_image
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
