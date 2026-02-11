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

Each project folder gets its own server instance with a unique port:

```bash
cd ~/projects/project1
./c-opencode.sh start  # Uses port 4100

cd ~/projects/project2
./c-opencode.sh start  # Uses port 4101

cd ~/projects/project3
./c-opencode.sh start  # Uses port 4102
```

### Available Commands

| Command | Description |
|---------|-------------|
| `run "prompt"` | Execute a task with the given prompt |
| `start` | Start the server (dynamic port allocation) |
| `start <port>` | Start on specific port (e.g., `start 4200`) |
| `stop` | Stop the current server |
| `status` | Show server status and health |
| `list` | List all running OpenCode servers |
| `list-sessions` | List all active sessions |
| `clean` | Remove stopped containers |
| `help` | Show this help message |

### Dynamic Port Allocation

- **Port Range**: 4100-4999 (supports up to 999 parallel projects)
- **Port File**: `.opencode-port` (gitignored) stores the assigned port
- **Automatic**: First available port is selected automatically
- **Persistent**: Same port reused for same project across terminals

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
# Shows: running on http://127.0.0.1:4100
```

**List all running servers:**
```bash
./c-opencode.sh list
# Shows all projects with their ports
```

**Stop and clean up:**
```bash
./c-opencode.sh stop
./c-opencode.sh clean  # Remove stopped containers
```

**Handle port conflicts:**
```bash
# If port 4100 is taken, use specific port
./c-opencode.sh start 4500

# Or stop existing and restart
./c-opencode.sh stop
./c-opencode.sh start
```

**Reset port assignment:**
```bash
rm .opencode-port  # Remove stale port file
./c-opencode.sh start  # Gets new port
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

1. **Port Discovery**: Script scans 4100-4999 for first available port
2. **Port Storage**: Port saved to `.opencode-port` in project folder
3. **Container Launch**: Docker container started with:
   - Port mapping: `127.0.0.1:<port>:4096`
   - Volume mounts for config and workspace
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
- **Port**: Internal port 4096 (mapped to dynamic host port)
- **Startup Command**: `opencode serve --hostname 127.0.0.1 --port 4096`

### Volume Mounts

| Host Path | Container Path | Mode | Purpose |
|-----------|----------------|------|---------|
| `~/.config/opencode` | `/root/.config/opencode` | `ro` | Configuration files |
| `~/.local/share/opencode` | `/root/.local/share/opencode` | `rw` | Cache and session data |
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
OPENCODE_HOST=127.0.0.1
OPENCODE_PORT=4096

# Node environment
NODE_ENV=production
```

### Advanced Port Management

**Force specific port:**
```bash
./c-opencode.sh start 4200
```

**Check port availability:**
```bash
lsof -i :4100-4999
```

**View port file:**
```bash
cat .opencode-port  # Shows: 4100
```

---

## Commands Reference

| Command | Example | Description |
|---------|---------|-------------|
| `run` | `./c-opencode.sh run "fix this bug"` | Execute prompt |
| `start` | `./c-opencode.sh start` | Start server (auto port) |
| `start` | `./c-opencode.sh start 4200` | Start server (specific port) |
| `stop` | `./c-opencode.sh stop` | Stop current server |
| `status` | `./c-opencode.sh status` | Check server status |
| `list` | `./c-opencode.sh list` | List all servers |
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

### Best Practices

1. Never expose port 4096 publicly
2. Keep API keys in host `~/.local/share/opencode`
3. Don't commit secrets—use `.env` with placeholders
4. Regular image updates
5. Use firewall rules if needed

---

## Troubleshooting

### Server won't start

```bash
# Check logs
./c-opencode.sh log  # If available, or check container directly:
docker logs opencode-server  # or check .opencode-container-id for container name

# Ensure directories exist
mkdir -p ~/.config/opencode
mkdir -p ~/.local/share/opencode

# Check permissions
ls -la ~/.config/opencode ~/.local/share/opencode
```

### Connection refused

```bash
# Verify running
./c-opencode.sh status

# Check port usage
lsof -i :4100-4999

# Restart
./c-opencode.sh stop
./c-opencode.sh start
```

### Port in use

```bash
# Stop existing
./c-opencode.sh stop

# Or use different port
./c-opencode.sh start 4500
```

### Permission denied

```bash
# Fix ownership
sudo chown -R $(whoami) ~/.config/opencode
sudo chown -R $(whoami) ~/.local/share/opencode
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
