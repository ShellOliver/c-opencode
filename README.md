# OpenCode Docker Setup with Server/Client Architecture

This Docker configuration provides a secure, containerized environment for the OpenCode AI coding agent using a **server/client architecture pattern**.

## Architecture Overview

### Server/Client Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                        Local Host                              │
│  ┌──────────────────┐         ┌──────────────────────────┐     │
│  │  c-opencode.sh   │────────>│  HTTP Client (@opencode-  │     │
│  │  (Local Wrapper) │  API    │   sdk)                   │     │
│  └──────────────────┘         └──────────────────────────┘     │
│                                         │                      │
│                                         ▼                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Docker Container                       │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  OpenCode Server (opencode serve)                  │  │  │
│  │  │  - Headless HTTP server on port 4096              │  │  │
│  │  │  - Runs as non-root user                           │  │  │
│  │  │  - Handles all AI agent operations                 │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│         ▲              ▲              ▲                        │
│         │              │              │                        │
│  ┌──────┴──────┐  ┌───┴──────┐  ┌───┴────────┐              │
│  │ ~/.config/  │  │ ~/.local/│  │  ./workspace│              │
│  │  opencode   │  │  share/  │  │   (project) │              │
│  │   (ro)      │  │ opencode │  │   (rw)      │              │
│  └─────────────┘  └──────────┘  └─────────────┘              │
```

### Why This Approach?

**Issue #12439**: The TUI has Docker issues. This server/client pattern solves:

- ✅ **TUI independence**: Server runs headless, no terminal issues
- ✅ **Client flexibility**: Any HTTP client can connect (Python, Node.js, curl, etc.)
- ✅ **Security**: Server runs in isolated container with minimal privileges
- ✅ **Configuration persistence**: Host configs mounted into container
- ✅ **Multi-client support**: Multiple clients can connect simultaneously

## Prerequisites

- Docker (v20+)
- Docker Compose (v2+)
- Node.js 22+ (for local wrapper)
- OpenCode API key configured on host

## Quick Start

### 1. Build the image

```bash
docker-compose build
```

### 2. Start the server

```bash
docker-compose up -d
```

### 3. Check server status

```bash
./c-opencode.sh status
```

### 4. Use the wrapper

```bash
# Run a task
./c-opencode.sh run "analyze this codebase"

# List sessions
./c-opencode.sh list-sessions

# Start a new session
./c-opencode.sh start myproject
```

## Directory Structure

```
opencode/
├── Dockerfile           # Container image definition
├── docker-compose.yaml  # Service definition
├── .dockerignore        # Files excluded from build
├── c-opencode.sh        # Local wrapper script
├── README.md           # This file
└── .gitignore          # Git ignore rules
```

## Configuration Mounting

### Volume Mappings

| Host Path | Container Path | Mode | Purpose |
|-----------|----------------|------|---------|
| `~/.config/opencode` | `/root/.config/opencode` | `ro` | Configuration files |
| `~/.local/share/opencode` | `/root/.local/share/opencode` | `rw` | Cache and session data |
| `./` (current dir) | `/workspace` | `rw` | Project workspace |

### Configuration Preserved from Host

- `opencode.json` - Main configuration with MCP servers
- API keys and tokens in auth directory
- Custom prompts and templates
- MCP server configurations

**Note**: Configuration remains on your host system, not in the container image.

## Local Wrapper Usage

The `c-opencode.sh` script provides a clean CLI interface:

### Commands

```bash
# Check server health
c-opencode.sh status

# Run a prompt
c-opencode.sh run "your prompt here"

# List sessions
c-opencode.sh list-sessions

# Start a new session
c-opencode.sh start [session-name]
```

### Environment Variables

Create a `.env` file in the project root:

```bash
# Server configuration (optional, defaults to 127.0.0.1:4096)
OPENCODE_HOST=127.0.0.1
OPENCODE_PORT=4096

# Node environment
NODE_ENV=production
```

## API Endpoints

The server exposes the following endpoints:

- `GET /health` - Health check
- `POST /run` - Execute a prompt
- `GET /sessions` - List sessions
- `POST /sessions` - Create new session
- `GET /sessions/{id}` - Get session details

See the OpenCode API documentation for full details.

## Security Notes

### ✅ Security Features

- Non-root user execution (UID 1000)
- Server runs on localhost only (127.0.0.1)
- No authentication built-in (relies on localhost isolation)
- Configuration preserved from host (not copied into image)
- Environment variables for sensitive data

### 🔒 Best Practices

1. **Never expose port 4096 publicly** - Only bind to 127.0.0.1
2. **Keep API keys secure** - Store in host `~/.local/share/opencode`
3. **Don't commit secrets** - Use `.env` with placeholders
4. **Regular updates** - Keep base images and dependencies updated
5. **Network restrictions** - Use firewall rules if needed

### Security Checklist

- [x] Non-root user
- [x] Localhost-only binding
- [x] No secrets in image
- [x] Config mounted from host
- [x] Auth data mounted from host
- [x] Minimal base image

## Troubleshooting

### Server won't start

```bash
# Check container logs
docker-compose logs

# Ensure directories exist
mkdir -p ~/.config/opencode
mkdir -p ~/.local/share/opencode

# Check permissions
ls -la ~/.config/opencode
ls -la ~/.local/share/opencode
```

### Connection refused

```bash
# Verify server is running
docker-compose ps

# Check if port is in use
lsof -i :4096

# Restart server
docker-compose restart
```

### Permission denied

```bash
# Fix directory permissions
sudo chown -R $(whoami) ~/.config/opencode
sudo chown -R $(whoami) ~/.local/share/opencode
```

### Update issues

```bash
# Clean rebuild
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

## Development

### Build locally

```bash
docker build -t opencode .
```

### Run interactively

```bash
docker run -it --rm \
  -v ~/.config/opencode:/root/.config/opencode:ro \
  -v ~/.local/share/opencode:/root/.local/share/opencode:rw \
  -v $(pwd):/workspace:rw \
  -p 127.0.0.1:4096:4096 \
  opencode \
  opencode serve --hostname 127.0.0.1 --port 4096
```

### Test API manually

```bash
# Health check
curl http://127.0.0.1:4096/health

# Run a prompt
curl -X POST http://127.0.0.1:4096/run \
  -H "Content-Type: application/json" \
  -d '{"prompt": "analyze this codebase"}'
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

MIT