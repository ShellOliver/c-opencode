#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
INSTALL_PATH="$LOCAL_BIN/c-opencode"

usage() {
    cat <<EOF
Usage: $(basename "$0")

Uninstall c-opencode (remove symbolic link).

This script removes the c-opencode symbolic link from ~/.local/bin
and cleanups the PATH configuration from ~/.bashrc.

Examples:
    $(basename "$0")    Uninstall c-opencode
EOF
    exit 0
}

uninstall() {
    echo "Uninstalling c-opencode..."
    
    if [[ -L "$INSTALL_PATH" ]]; then
        TARGET=$(readlink "$INSTALL_PATH")
        rm "$INSTALL_PATH"
        echo "Removed symbolic link: $INSTALL_PATH -> $TARGET"
    elif [[ -f "$INSTALL_PATH" ]]; then
        rm "$INSTALL_PATH"
        echo "Removed file: $INSTALL_PATH"
    else
        echo "c-opencode not found at $INSTALL_PATH (already uninstalled?)"
        exit 0
    fi
    
    echo ""
    echo "Removing c-yolo agent..."
    remove_c_yolo_agent
    
    echo ""
    echo "Cleaning up ~/.bashrc PATH configuration..."
    if [[ -f "$HOME/.bashrc" ]]; then
        if grep -q "# Added by c-opencode installer" "$HOME/.bashrc" 2>/dev/null; then
            sed -i.bak '/# Added by c-opencode installer/d; /^export PATH="\$HOME\/\.local\/bin:\$PATH"/d' "$HOME/.bashrc"
            rm -f "$HOME/.bashrc.bak"
            echo "Updated ~/.bashrc"
        else
            echo "No c-opencode PATH entry found in ~/.bashrc (may have been removed manually)"
        fi
    fi
    
    echo ""
    echo "Uninstallation complete."
    echo "Please restart your shell or run: source ~/.bashrc"
}

remove_c_yolo_agent() {
    local agent_file="$HOME/.config/opencode/agents/c-yolo.md"
    local config_file="$HOME/.config/opencode/opencode.json"
    
    if [ -f "$agent_file" ]; then
        rm "$agent_file"
        echo "Removed c-yolo agent file: $agent_file"
    else
        echo "c-yolo agent file not found (may have been removed already)"
    fi
    
    if [ -f "$config_file" ]; then
        if command -v jq &> /dev/null; then
            if jq -e '.agent["c-yolo"]' "$config_file" &> /dev/null; then
                echo "Removing c-yolo configuration from opencode.json..."
                local temp_config
                temp_config=$(mktemp)
                jq 'del(.agent["c-yolo"])' "$config_file" > "$temp_config"
                mv "$temp_config" "$config_file"
                echo "Removed c-yolo configuration from opencode.json"
            else
                echo "c-yolo configuration not found in opencode.json"
            fi
        else
            echo "Warning: jq not found. Cannot update opencode.json"
            echo "Please manually remove c-yolo configuration from opencode.json"
        fi
    else
        echo "opencode.json not found at $config_file"
    fi
}

if [[ $# -eq 0 ]]; then
    uninstall
    exit 0
fi

case "${1:-}" in
    -h|--help)
        usage
        ;;
    *)
        echo "Error: Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac
