# OpenCode Docker Setup

A containerized environment for the OpenCode AI coding agent with server/client architecture and multi-project support.

---

## Quick Start

```bash
# One-time setup
./c-opencode.sh

# Start server in your project
cd /path/to/project
./c-opencode.sh start

# Run tasks
./c-opencode.sh run "analyze this codebase"
./c-opencode.sh status
```

---

## Usage Guide

### Installation (One-Time Setup)

The wrapper script `c-opencode.sh` is included in the repository. No additional installation needed.

```bash
# Verify the script exists
ls -la c-opencode.sh

# Make it executable if needed
chmod +x c-opencode.sh
```

### Running from Different Folders

Each project folder gets its own server instance with a unique container:

```bash
cd ~/projects/project1
./c-opencode.sh start  # Creates container opencode-<hash1>

cd ~/projects/project2
./c-opencode.sh start  # Creates container opencode-<hash2>

cd ~/projects/project3
./c-opencode.sh start  # Creates container opencode-<hash3>
```

Container naming uses MD5 hash of the canonical project path to ensure uniqueness.

### Available Commands

| Command | Description |
|---------|-------------|
| `start` | Start the server (Docker assigns port automatically) |
| `stop` | Stop the current server |
| `restart` | Restart the server |
| `status` | Show server status and port |
| `logs` | View container logs |
| `run "prompt"` | Execute a task with the given prompt |
| `list` | List all OpenCode containers |
| `list-sessions` | List all active sessions |
| `clean` | Remove stopped containers |
| `help` | Show this help message |

### Automatic Port Assignment

- **Port Assignment**: Docker assigns ports automatically from ephemeral range
- **Port Retrieval**: Query Docker directly for assigned port
- **Localhost Only**: All ports bound to 127.0.0.1 for security

### Examples

**Basic workflow:**
```bash
cd ~/my-project
./c-opencode.sh start
./c-opencode.sh run "debug this module"
./c-opencode.sh status
```

**Check server status:**
```bash
./c-opencode.sh status
# Shows: Server is running on http://127.0.0.1:<port>
```

**List all containers:**
```bash
./c-opencode.sh list
# Shows all projects with their container names and ports
```

**View logs:**
```bash
./c-opencode.sh logs
```

**Stop and clean up:**
```bash
./c-opencode.sh stop
./c-opencode.sh clean  # Remove stopped containers
```

---

## How It Works

### Architecture Overview

```
Local Host                          Docker Container
┌──────────────────┐         ┌──────────────────────────┐
│  c-opencode.sh   │────────>│  OpenCode Server         │
│  (Local Wrapper) │  API    │  - HTTP server on 4096   │
└──────────────────┘         │  - Non-root execution    │
                             └──────────────────────────┘
```

### What Happens in Background

1. **Container Naming**: Script computes MD5 hash of project path for unique container name
2. **Container Launch**: Docker container started with:
   - Port mapping: `127.0.0.1::4096` (Docker assigns port)
   - Labels for project discovery
   - Volume mounts for config and workspace
3. **Port Discovery**: Query Docker for assigned port via `docker port`
4. **Server Start**: OpenCode server starts in headless mode
5. **Client Request**: Wrapper sends HTTP requests to server

### Server/Client Pattern

- **Server**: Runs in container, executes AI operations
- **Client**: `c-opencode.sh` wrapper sends HTTP requests
- **Benefits**:
  - TUI independence (no terminal issues)
  - Multiple clients can connect
  - Security through isolation
  - Configuration persistence from host

---

## Architecture Details

### Container Setup

- **Base Image**: Minimal Node.js 22+ image
- **User**: Non-root user (UID 1000)
- **Port**: Internal port 4096 (Docker assigns host port dynamically)
- **Startup Command**: `opencode serve --hostname 0.0.0.0 --port 4096`

### Container Labels

- `opencode.managed=true` - Marks container as managed by wrapper
- `opencode.path=/path/to/project` - Tracks project path

### Volume Mounts

| Host Path | Container Path | Mode | Purpose |
|-----------|----------------|------|---------|
| `~/.config/opencode` | `/home/node/.config/opencode` | `ro` | Configuration files |
| `~/.local/share/opencode` | `/home/node/.local/share/opencode` | `rw` | Cache and session data |
| `~/.local/state` | `/home/node/.local/state` | `rw` | State data |
| `./` (project folder) | `/workspace` | `rw` | Project workspace |

### Configuration Flow

1. Host loads `opencode.json` and auth files
2. Directories mounted into container at startup
3. OpenCode server reads config from container paths
4. Changes persist on host (not in container image)

---

## Configuration

### Environment Variables

Create `.env` in project root (optional):

```bash
# Server configuration
OPENCODE_HOST=0.0.0.0
OPENCODE_PORT=4096

# Node environment
NODE_ENV=production
```

---

## Commands Reference

| Command | Example | Description |
|---------|---------|-------------|
| `start` | `./c-opencode.sh start` | Start server (auto port) |
| `stop` | `./c-opencode.sh stop` | Stop current server |
| `restart` | `./c-opencode.sh restart` | Restart server |
| `status` | `./c-opencode.sh status` | Check server status |
| `logs` | `./c-opencode.sh logs` | View container logs |
| `run` | `./c-opencode.sh run "fix this bug"` | Execute prompt |
| `list` | `./c-opencode.sh list` | List all containers |
| `list-sessions` | `./c-opencode.sh list-sessions` | List sessions |
| `clean` | `./c-opencode.sh clean` | Remove stopped containers |
| `help` | `./c-opencode.sh help` | Show help |

---

## Security

### Features

- Non-root container execution
- Localhost-only binding (127.0.0.1)
- No authentication (relies on localhost isolation)
- Configuration preserved from host
- API keys mounted from host
- Docker labels for project discovery

### Best Practices

1. Never expose ports publicly
2. Keep API keys in host `~/.local/share/opencode`
3. Don't commit secrets—use `.env` with placeholders
4. Regular image updates
5. Use firewall rules if needed

---

## Troubleshooting

### Server won't start

```bash
# Check logs
./c-opencode.sh logs

# Or check container directly:
docker ps -a --filter "label=opencode.managed=true"

# Ensure directories exist
mkdir -p ~/.config/opencode
mkdir -p ~/.local/share/opencode
mkdir -p ~/.local/state

# Check permissions
ls -la ~/.config/opencode ~/.local/share/opencode ~/.local/state
```

### Connection refused

```bash
# Verify running
./c-opencode.sh status

# Check containers
docker ps -a --filter "label=opencode.managed=true"

# Restart
./c-opencode.sh stop
./c-opencode.sh start
```

### Permission denied

```bash
# Fix ownership
sudo chown -R $(whoami) ~/.config/opencode
sudo chown -R $(whoami) ~/.local/share/opencode
sudo chown -R $(whoami) ~/.local/state
```

### Update issues

```bash
# Clean rebuild
./c-opencode.sh stop
./c-opencode.sh clean
./c-opencode.sh start
```

---

## Contributing

Contributions welcome!

1. Fork repository
2. Create feature branch
3. Make changes
4. Submit pull request

---

## License

MIT
