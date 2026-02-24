# OpenCode Docker Setup

A containerized environment for the OpenCode AI coding agent with server/client architecture and multi-project support.

---

## Quick Start

```bash
# Start server in your project
cd /path/to/project
./c-opencode.sh start

# Open browser UI
./c-opencode.sh attach
```

---

## Installation

The wrapper script `c-opencode.sh` is included in the repository.

```bash
# Make executable
chmod +x c-opencode.sh
```

---

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `start` | Start the OpenCode server |
| `attach` | Open OpenCode UI in browser |
| `stop` | Stop the server |
| `restart` | Restart the server |
| `status` | Show server status |
| `logs` | View container logs |
| `list` | List all OpenCode containers |
| `worktree` | Create worktree manually |
| `worktree remove` | Remove worktree |
| `clean` | Remove container and worktree |
| `help` | Show help message |

### Start Options

| Option | Description |
|--------|-------------|
| `-p, --port <port>` | Expose additional container port |
| `--public` | Bind to 0.0.0.0 (requires `OPENCODE_SERVER_PASSWORD`) |

### Global Options

| Option | Description |
|--------|-------------|
| `--worktree` | Use git worktree for isolation |

---

## Examples

```bash
# Start server (current directory mounted)
./c-opencode.sh start

# Start with public access
./c-opencode.sh start --public

# Expose port 3000 in container
./c-opencode.sh start -p 3000

# Start with git worktree isolation
./c-opencode.sh --worktree start

# Open browser UI
./c-opencode.sh attach

# Check server status
./c-opencode.sh status

# View logs
./c-opencode.sh logs

# Stop server
./c-opencode.sh stop

# Clean up (remove container + worktree)
./c-opencode.sh clean
```

---

## How It Works

### Architecture

```
Local Host                          Docker Container
┌──────────────────┐         ┌──────────────────────────┐
│  c-opencode.sh   │────────>│  OpenCode Server         │
│  (Local Wrapper) │  API    │  - HTTP server on 4096   │
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
./c-opencode.sh start  # Creates container opencode-<hash1>

cd ~/projects/project2
./c-opencode.sh start  # Creates container opencode-<hash2>
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

## Troubleshooting

```bash
# Check status
./c-opencode.sh status

# View logs
./c-opencode.sh logs

# Restart
./c-opencode.sh restart

# Full cleanup
./c-opencode.sh clean
```

---

## License

MIT
