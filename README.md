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

## Container Configuration

Create a `.opencode/container.yaml` file to configure port mappings for services running inside the container. This allows you to expose additional ports without editing the Dockerfile.

### Format

```yaml
ports:
  - "3000:3000"
  - "8080:8080"
  - "127.0.0.1:5000:5000"
```

### Port Mapping Formats

| Format | Description |
|---------|-------------|
| `"3000"` | Expose port 3000 on random host port |
| `"3000:3000"` | Map host port 3000 to container port 3000 |
| `"8080:3000"` | Map host port 8080 to container port 3000 |
| `"127.0.0.1:5000:5000"` | Bind to localhost only |

### Example

```bash
# Create .opencode directory
mkdir .opencode

# Create container.yaml
cat > .opencode/container.yaml <<'EOF'
ports:
  - "3000:3000"
  - "8080:8080"
  - "127.0.0.1:5000:5000"
EOF

# Start container (ports will be exposed)
c-opencode
```

### Requirements

The `yq` binary (YAML parser) is bundled with this package and automatically installed during setup. No additional dependencies required.

### Metadata

Custom images include labels for easy identification:
```bash
docker inspect opencode-<foldername>:latest | jq '.[0].Config.Labels'
```

**Security Note:** The custom build script runs as `node` user inside container during build time, not on your host system.

---

## Custom Build Scripts

Create a `.opencode/c-opencode-image.sh` file to customize the Docker image for your project. The script runs **inside** the container during the build process, allowing you to:

- Install project-specific dependencies
- Run build commands
- Add system tools and packages

### Example: Node.js Project

```bash
mkdir .opencode
cat > .opencode/c-opencode-image.sh <<'EOF'
#!/bin/bash
set -e
cd /workspace/project
npm install
npm run build
EOF
chmod +x .opencode/c-opencode-image.sh
```

### Example: Python Project

```bash
mkdir .opencode
cat > .opencode/c-opencode-image.sh <<'EOF'
#!/bin/bash
set -e
apt-get update && apt-get install -y python3-pip
cd /workspace/project
pip install -r requirements.txt
EOF
chmod +x .opencode/c-opencode-image.sh
```

### Rebuilding Custom Images

The custom image is **NOT automatically rebuilt** when you modify `.opencode/c-opencode-image.sh`. You must manually rebuild:

```bash
c-opencode --rebuild-image
```

The custom image is named `opencode-<foldername>:latest` (folder name sanitized to be Docker-compatible).

**Metadata:**
Custom images include labels for easy identification:
```bash
docker inspect opencode-<foldername>:latest | jq '.[0].Config.Labels'
```

**Security Note:** The custom build script runs as the `node` user inside the container during build time, not on your host system.

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
