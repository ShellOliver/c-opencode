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
