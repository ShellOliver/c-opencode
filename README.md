# OpenCode Docker Setup

Containerized OpenCode AI coding agent with server/client architecture.

## Quick Start

```bash
# Install (one-time setup)
./install.sh

# Start server and attach TUI
cd /path/to/project
c-opencode

# Show server URL
c-opencode web
```

## Configuration

### Port Mappings (.opencode/container.yaml)

Create `.opencode/container.yaml` to expose additional ports:

```yaml
ports:
  - "3000:3000"           # Map host 3000 to container 3000
  - "8080:3000"           # Map host 8080 to container 3000
  - "127.0.0.1:5000:5000" # Bind to localhost only
  - "3000"                # Random host port
```

### Custom Build Scripts (.opencode/c-opencode-image.sh)

Create `.opencode/c-opencode-image.sh` to customize the container image:

```bash
#!/bin/bash
set -e
cd /workspace/project
npm install
npm run build
```

Rebuild after modifying: `c-opencode --rebuild-image`

## Commands

| Command | Description |
|---------|-------------|
| `c-opencode` | Start server and attach TUI |
| `c-opencode web` | Show server URL |
| `c-opencode --rebuild-image` | Force rebuild custom image |
| `c-opencode help` | Show help |

Pass-through commands work too:
```bash
c-opencode run 'add feature'
c-opencode session list
```

## Architecture

```
Host (c-opencode CLI) --> Docker Container (OpenCode Server on port 4096)
```

- Each project gets its own container (hash-based naming)
- Volumes: `~/.config/opencode`, `~/.local/share/opencode`, `~/.local/state`, `./project`
- Default binds to 127.0.0.1 for security

## Troubleshooting

```bash
c-opencode status    # Check container status
c-opencode logs      # View container logs
docker ps            # List running containers
docker logs <name>    # Show logs
docker stop <name>    # Stop container
```

## Uninstall

```bash
./uninstall.sh
```
