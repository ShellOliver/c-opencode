# Opencode AI Coding Agent Docker Setup

This Docker configuration provides a secure, containerized environment for the opencode AI coding agent CLI tool.

## Key Principles

- **Preserves host configuration**: opencode.json and MCP configs remain on host
- **Preserves authentication**: Auth credentials are stored in host directories
- **Security-focused**: Non-root user, minimal privileges
- **Clean setup**: Simple bind mounts for configuration and repositories

## Directory Structure

```
opencode/
├── docker-compose.yaml    # Service definition
├── Dockerfile            # Container image definition
├── .dockerignore         # Files excluded from build context
├── README.md            # This file
└── .gitignore           # Git ignore rules
```

## Quick Start

### 1. Build the image

```bash
docker-compose build
```

### 2. Run opencode commands

```bash
docker-compose run --rm opencode <command>
```

Examples:

```bash
# View help
docker-compose run --rm opencode --help

# Run with a specific task
docker-compose run --rm opencode "analyze the codebase and identify potential security issues"

# Interactive mode
docker-compose run --rm opencode
```

## Configuration

### opencode.json

Your opencode configuration file should be located at:
- **Linux/Mac**: `~/.config/opencode/opencode.json`
- **Windows**: `%APPDATA%\opencode\opencode.json`

This directory is mounted into the container, preserving all your settings including MCP server configurations.

### MCP Server Configuration

MCP servers configured in your opencode.json are automatically available in the container because:
- The `~/.config/opencode/` directory is bind-mounted
- All MCP server definitions persist from host to container
- No additional configuration needed

### Authentication

Authentication credentials are stored in `~/.local/share/opencode/` on the host and mounted into the container, ensuring your API keys and tokens remain secure on your host system.

## Usage

### Working with Projects

The current directory is mounted as `/workspace` in the container:

```bash
# Run opencode on the current project
docker-compose run --rm opencode "analyze this codebase"

# Run with a specific project directory
docker-compose run --rm opencode -d /workspace/path/to/project "do something"
```

### Environment Variables

You can add environment variables in a `.env` file:

```
OPENAI_API_KEY=your-key-here
ANTHROPIC_API_KEY=your-key-here
```

Or pass them directly:

```bash
docker-compose run --rm -e OPENAI_API_KEY=xxx opencode "task"
```

## Docker Compose Configuration

### Volumes

- `./:/workspace` - Current project directory
- `~/.config/opencode:/root/.config/opencode` - Configuration files
- `~/.local/share/opencode:/root/.local/share/opencode` - Authentication data

### User

Runs as non-root user `opencode` (UID 1000) for security.

## Security Considerations

### ✅ Good Practices

- Non-root user execution
- No secrets baked into image
- Configuration kept on host
-最小权限原则

### Recommendations

1. **Never commit** `.env` files with secrets
2. **Use `.env.example`** with placeholder values
3. **Protect auth data** - the `~/.local/share/opencode` directory contains sensitive information
4. **Restrict network access** - only allow necessary API endpoints
5. **Regular updates** - keep base images and dependencies updated

### Security Checklist

- [x] Non-root user
- [x] No secrets in image
- [x] Config mounted from host
- [x] Auth data mounted from host
- [x] Minimal base image
- [ ] Network restrictions (configure based on needs)

## Multi-Project Setup

To use opencode with multiple projects:

```bash
# Project 1
cd /path/to/project1
docker-compose run --rm opencode "task for project 1"

# Project 2
cd /path/to/project2
docker-compose run --rm opencode "task for project 2"
```

Each project uses the same configuration from your host.

## Troubleshooting

### Permission Denied

Ensure your opencode directories exist:

```bash
mkdir -p ~/.config/opencode
mkdir -p ~/.local/share/opencode
```

### MCP Server Not Working

Check that your `~/.config/opencode/opencode.json` contains valid MCP server configurations.

### Build Errors

Clean build cache:

```bash
docker-compose build --no-cache
```

## Customization

### Adding Dependencies

Modify the `Dockerfile` to add additional tools:

```dockerfile
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

### Changing Base Image

Edit the `FROM` instruction in `Dockerfile`:

```dockerfile
FROM node:22-alpine
```

## License

MIT
