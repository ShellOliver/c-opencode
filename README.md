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

## Alternatives

Different sandboxing approaches solve the same fundamental challenge: limiting AI agent access to the host system while maintaining functionality. Each approach offers distinct trade-offs in isolation, resource usage, and performance.

### Docker Sandbox / MicroVM-Based Isolation

MicroVM-based sandboxes (e.g., Firecracker, Docker Sandboxes) provide hardware-level isolation by running each environment in a separate virtual machine with its own kernel. This approach offers security comparable to running code on a dedicated machine. Platforms like AWS Lambda and AWS Fargate use this technology for multi-tenant isolation. The primary trade-offs include higher resource consumption, longer cold start times (~150ms optimized), and increased memory overhead due to running separate kernel instances. This isolation model is ideal for production environments requiring the strongest security boundaries.

### Container-Based Isolation

Container-based sandboxes use Linux namespaces and cgroups to create isolated environments that share the host kernel. This approach balances isolation strength with resource efficiency, offering faster startup times and lower memory consumption compared to microVMs. The c-opencode tool uses this approach, running commands in isolated containers while maintaining access to necessary host resources. Security can be enhanced with seccomp profiles to filter syscalls. This model works well for development workflows where users trust the AI agent but want protection against accidental damage.

### Permission-Based Sandboxing

Permission-based sandboxes leverage operating system security features through a layered architecture that combines kernel-enforced restrictions with interactive approval. Tools like [nono](https://nono.sh) use Landlock (Linux 5.13+) with seccomp-notify, or Seatbelt (macOS), to create an unprivileged sandbox. The architecture consists of two layers: a static kernel-enforced floor (Landlock/Seatbelt) that provides irreversible restrictions, and a dynamic seccomp-notify layer that traps `openat`/`openat2` syscalls and routes them to a trusted supervisor process for interactive approval. The supervisor opens files and injects file descriptors into the untrusted child process, allowing the agent to work transparently without modification. This approach runs entirely unprivileged (no root or CAP_SYS_ADMIN required), provides minimal overhead (3-10 microseconds on file opens), and strong kernel-enforced isolation. The trade-off is the need to share some filesystem metadata for the supervisor to validate requests, and an interactive approval workflow for file access.

### Comparison Summary

| Approach | Isolation Strength | Resource Usage | Startup Time | Use Case |
|----------|-------------------|----------------|---------------|----------|
| Docker Sandbox / MicroVM | Strongest (hardware-level) | High (separate kernels) | Slower (~150ms) | Multi-tenant production, untrusted code |
| Container-Based | Strong (kernel-level) | Moderate (shared kernel) | Fast (<1s) | Development, trusted AI agents |
| Permission-Based | Strong (kernel-enforced) | Lowest | Fastest (<100ms) | Performance-critical scenarios, interactive approval |

Each approach serves different needs. The choice depends on your threat model, performance requirements, and trust level in the AI agent. Container-based isolation, as implemented by c-opencode, offers a practical balance for most development workflows.

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
