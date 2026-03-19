#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C_OPEXECUTE_SCRIPT="$SCRIPT_DIR/c-opencode.sh"
LOCAL_BIN="$HOME/.local/bin"
INSTALL_PATH="$LOCAL_BIN/c-opencode"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install or uninstall c-opencode.

Options:
    --uninstall    Remove c-opencode installation
    -h, --help     Show this help message

Examples:
    $(basename "$0")              Install c-opencode
    $(basename "$0") --uninstall  Uninstall c-opencode
EOF
    exit 0
}

uninstall() {
    echo "Uninstalling c-opencode..."

    if [[ -L "$INSTALL_PATH" ]]; then
        rm "$INSTALL_PATH"
        echo "Removed symbolic link: $INSTALL_PATH"
    elif [[ -f "$INSTALL_PATH" ]]; then
        rm "$INSTALL_PATH"
        echo "Removed file: $INSTALL_PATH"
    else
        echo "c-opencode not found at $INSTALL_PATH (already uninstalled?)"
        exit 0
    fi

    echo "Uninstallation complete."
}

install_c_yolo_agent() {
    local agent_file="$SCRIPT_DIR/c-yolo.md"
    local agents_dir="$HOME/.config/opencode/agents"
    local config_file="$HOME/.config/opencode/opencode.json"
    local target_agent="$agents_dir/c-yolo.md"

    if [ ! -f "$agent_file" ]; then
        echo "Warning: c-yolo.md not found in $SCRIPT_DIR"
        return 0
    fi

    mkdir -p "$agents_dir"

    if [ -f "$target_agent" ]; then
        echo "c-yolo agent already exists at $target_agent"
    else
        cp "$agent_file" "$target_agent"
        echo "Installed c-yolo agent to $target_agent"
    fi

    if [ -f "$config_file" ]; then
        if command -v jq &> /dev/null; then
            if ! jq -e '.agent["c-yolo"]' "$config_file" &> /dev/null; then
                echo "Adding c-yolo configuration to opencode.json..."
                local temp_config
                temp_config=$(mktemp)
                jq '.agent["c-yolo"] = {
                    "enabled": false,
                    "description": "Primary YOLO agent that executes tasks immediately without asking for permissions",
                    "mode": "primary",
                    "permission": {
                        "bash": "allow",
                        "edit": "allow",
                        "read": "allow",
                        "write": "allow",
                        "webfetch": "allow"
                    }
                }' "$config_file" > "$temp_config"
                mv "$temp_config" "$config_file"
                echo "c-yolo agent configuration added (disabled by default)"
            else
                echo "c-yolo configuration already exists in opencode.json"
            fi
        else
            echo "Warning: jq not found. Cannot update opencode.json"
            echo "Please manually add c-yolo configuration with enabled: false"
        fi
    else
        echo "Warning: opencode.json not found at $config_file"
    fi
}

install() {
    echo "Installing c-opencode..."

    if [[ ! -f "$C_OPEXECUTE_SCRIPT" ]]; then
        echo "Error: c-opencode.sh not found at $C_OPEXECUTE_SCRIPT"
        echo "Please ensure c-opencode.sh exists in the same directory as this install script."
        exit 1
    fi

    if [[ ! -r "$C_OPEXECUTE_SCRIPT" ]]; then
        echo "Error: c-opencode.sh is not readable. Check file permissions."
        exit 1
    fi

    if [[ ! -x "$C_OPEXECUTE_SCRIPT" ]]; then
        echo "Error: c-opencode.sh is not executable. Please make it executable:"
        echo "  chmod +x $C_OPEXECUTE_SCRIPT"
        exit 1
    fi

    mkdir -p "$LOCAL_BIN"

    if [[ -e "$INSTALL_PATH" ]] && [[ ! -L "$INSTALL_PATH" ]]; then
        echo "Error: $INSTALL_PATH exists but is not a symbolic link."
        echo "Please remove it manually or use --uninstall."
        exit 1
    fi

    if [[ -L "$INSTALL_PATH" ]]; then
        echo "Symbolic link already exists at $INSTALL_PATH"
        echo "Checking if it points to the correct location..."

        CURRENT_TARGET=$(readlink "$INSTALL_PATH")
        if [[ "$CURRENT_TARGET" == "$C_OPEXECUTE_SCRIPT" ]]; then
            echo "Symbolic link is already correctly configured."
        else
            echo "Removing existing symbolic link pointing to: $CURRENT_TARGET"
            rm "$INSTALL_PATH"
        fi
    fi

    if [[ ! -L "$INSTALL_PATH" ]]; then
        ln -s "$C_OPEXECUTE_SCRIPT" "$INSTALL_PATH"
    fi

    if [[ ! -L "$INSTALL_PATH" ]]; then
        echo "Error: Failed to create symbolic link."
        exit 1
    fi

    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo "Adding $LOCAL_BIN to PATH..."

        if [[ -f "$HOME/.bashrc" ]]; then
            if ! grep -q "export PATH=\"\$HOME/\.local/bin:\$PATH\"" "$HOME/.bashrc" 2>/dev/null; then
                cat <<EOF >> "$HOME/.bashrc"

# Added by c-opencode installer
export PATH="\$HOME/.local/bin:\$PATH"
EOF
                echo "Updated ~/.bashrc"
            else
                echo "~/.bashrc already contains PATH configuration"
            fi
        else
            echo "Warning: ~/.bashrc not found. PATH may need to be configured manually."
        fi

        export PATH="$LOCAL_BIN:$PATH"
    fi

    if ! command -v c-opencode &>/dev/null; then
        echo "Error: c-opencode command not found after installation."
        echo "Please restart your shell or run: source ~/.bashrc"
        exit 1
    fi

    echo "Installing yq (YAML parser)..."

    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        i386|i686) ARCH="386" ;;
        *) ARCH="amd64" ;;
    esac

    YQ_SOURCE="${SCRIPT_DIR}/bin/yq_${OS}_${ARCH}"

    if [ ! -f "$YQ_SOURCE" ]; then
        echo "Warning: yq binary not found for your platform (${OS}_${ARCH})"
        echo "container.yaml port configuration will not work."
    else
        if cp "$YQ_SOURCE" "$LOCAL_BIN/yq" 2>/dev/null; then
            chmod +x "$LOCAL_BIN/yq"
            echo "yq installed to $LOCAL_BIN/yq"
        else
            echo "Warning: Could not install yq to $LOCAL_BIN"
            echo "Using bundled yq binary instead."
        fi
    fi

    echo "Installing c-yolo agent..."
    install_c_yolo_agent

    echo "Installation complete!"
    echo "Run 'c-opencode --help' to get started."
}

if [[ $# -eq 0 ]]; then
    install
    exit 0
fi

case "${1:-}" in
    --uninstall)
        uninstall
        ;;
    -h|--help)
        usage
        ;;
    *)
        echo "Error: Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac
