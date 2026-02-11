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
            return 0
        else
            echo "Removing existing symbolic link pointing to: $CURRENT_TARGET"
            rm "$INSTALL_PATH"
        fi
    fi

    ln -s "$C_OPEXECUTE_SCRIPT" "$INSTALL_PATH"

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
