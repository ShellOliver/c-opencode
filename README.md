# OpenCode Docker Setup

A containerized environment for the OpenCode AI coding agent with server/client architecture and multi-project support.

---

## Quick Start

```bash
# Install c-opencode (one-time setup)
./install.sh

# Start server in your project
cd /path/to/project
c-opencode

# Show server URL for browser
c-opencode web
```

---

## Installation

Run the installer to set up the `c-opencode` command:

```bash
./install.sh
```

This creates a symbolic link in `~/.local/bin` and adds it to your PATH.

To uninstall, run:

```bash
./uninstall.sh
```

---

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `(no args)` | Start server and attach to OpenCode TUI |
| `web` | Show server URL |
| `help` | Show help message |

### Pass-through

Any other arguments are passed to opencode with the `--attach` flag. The server URL is automatically included.

Examples:
```bash
c-opencode run 'add feature'
c-opencode session list
c-opencode stats
c-opencode models
```

### Container Management

Use Docker directly to manage containers:

```bash
docker ps                          # List running containers
docker logs <container>            # Show logs
docker stop <container>            # Stop container
docker rm <container>              # Remove container
```

---

## Examples

```bash
# Attach to OpenCode TUI
c-opencode

# Show server URL for browser
c-opencode web

# Run opencode non-interactively
c-opencode run 'add feature'

# List sessions
c-opencode session list

# Show usage statistics
c-opencode stats

# List available models
c-opencode models
```

---

## How It Works

### Architecture

```
Local Host                          Docker Container
┌──────────────────┐         ┌──────────────────────────┐
│    c-opencode    │────────>│  OpenCode Server         │
│  (CLI Command)   │  API    │  - HTTP server on 4096   │
└──────────────────┘         │  - Working dir: /workspace/project
                             └──────────────────────────┘
```

### What Happens

1. **Container Naming**: MD5 hash of project path ensures unique container name
2. **Image Build**: Automatically builds from `Dockerfile` if not present
3. **Container Launch**: Starts with:
   - Port mapping (Docker assigns host port)
   - Volume mounts for config and project
   - Working directory: `/workspace/project`
4. **Server Start**: OpenCode server starts in headless mode
5. **Attach**: Opens browser UI pointing to `/workspace/project`

### Multi-Project Support

Each project folder gets its own server instance:

```bash
cd ~/projects/project1
c-opencode start  # Creates container opencode-<hash1>

cd ~/projects/project2
c-opencode start  # Creates container opencode-<hash2>
```

---

## Container Details

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `~/.config/opencode` | `/home/node/.config/opencode` | Configuration |
| `~/.local/share/opencode` | `/home/node/.local/share/opencode` | Cache & sessions |
| `~/.local/state` | `/home/node/.local/state` | State data |
| `./` (project) | `/workspace/project` | Project workspace |

### Labels

- `opencode.managed=true` - Managed by wrapper
- `opencode.path=/path/to/project` - Project path

---

## Security

- Non-root container execution
- Localhost-only binding (127.0.0.1) by default
- Use `--public` with `OPENCODE_SERVER_PASSWORD` for remote access
- API keys mounted from host

---

## Uninstall

To remove the `c-opencode` command:

```bash
./uninstall.sh
```

This removes the symbolic link from `~/.local/bin` and cleans up the PATH entry in `~/.bashrc`.

---

## Troubleshooting

```bash
# Check status
c-opencode status

# View logs
c-opencode logs

# Restart
c-opencode restart

# Full cleanup
c-opencode clean
```

---

## License

MIT
