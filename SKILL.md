# OpenCode Docker Wrapper

A Docker-based wrapper for running OpenCode with isolated git worktrees.

## Installation

```bash
# Ensure opencode Docker image is built
docker build -t opencode:latest .

# Add to PATH (optional)
# cp c-opencode.sh /usr/local/bin/c-opencode
```

## Quick Start

```bash
# Set password (recommended: add to .bashrc/.zshrc)
export OPENCODE_SERVER_PASSWORD=your-password

# Start server - automatically creates worktree in .git/worktrees/
c-opencode
```

## Commands

| Command | Description |
|---------|-------------|
| `c-opencode` | Start server (shorthand) |
| `c-opencode start` | Start the OpenCode server |
| `c-opencode attach` | Attach to server with OpenCode CLI |
| `c-opencode run "prompt"` | Execute a prompt |
| `c-opencode stop` | Stop the server |
| `c-opencode restart` | Restart the server |
| `c-opencode status` | Check server health |
| `c-opencode logs` | View container logs |
| `c-opencode list` | List all servers |
| `c-opencode worktree` | Create isolated worktree |
| `c-opencode worktree remove` | Remove worktree |
| `c-opencode clean` | Stop container and remove worktree |

## Options

| Option | Description |
|--------|-------------|
| `-p, --port <port>` | Expose additional container port |
| `--public` | Bind to 0.0.0.0 (requires `OPENCODE_SERVER_PASSWORD`) |

## Examples

### Basic Usage

```bash
# Start server - automatically creates worktree in .git/worktrees/
c-opencode

# Attach to server
c-opencode attach

# Run a prompt
c-opencode run "explain this codebase"
```

### Expose Additional Ports

```bash
# Expose port 3000 (e.g., for a dev server inside container)
c-opencode start -p 3000

# Multiple ports
c-opencode start -p 3000 -p 8080
```

### Public Access

```bash
# Set password (required for --public flag)
export OPENCODE_SERVER_PASSWORD=your-password

# Start with public access (accessible at http://0.0.0.0:<port>)
c-opencode start --public
```

### Cleanup

```bash
# Stop server and remove worktree
c-opencode clean
```

## How It Works

- When you start the server, it automatically creates a git worktree in `.git/worktrees/opencode-<hash>/`
- The worktree is mounted into the container as `/workspace`
- This provides isolation - changes in the container don't affect your main project
- `.env*` files are automatically copied to the worktree
- `c-opencode clean` removes both the container and worktree
