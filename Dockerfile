# syntax=docker/dockerfile:1

# Use Debian-based Node.js 22 for full tool compatibility
FROM node:22-bookworm

# Labels
LABEL maintainer="opencode"
LABEL description="OpenCode AI coding agent server container"

# Install essential dev tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 \
    curl \
    wget \
    bash \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /home/node

USER root

RUN mkdir -p /home/node/.config/opencode && chown -R node:node /home/node/.config/opencode
RUN mkdir -p /home/node/.local/share/opencode && chown -R node:node /home/node/.local/share/opencode
RUN mkdir -p /home/node/.local/state && chown -R node:node /home/node/.local/state

# Use the existing node user (UID 1000, GID 1000) instead of creating a duplicate
USER node

# Install OpenCode using official installer
RUN curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path

# Set environment variables
ENV NODE_ENV=production
ENV HOME=/home/node
ENV PATH="$HOME/.opencode/bin:$PATH"

# Expose the opencode server port
EXPOSE 4096

# Default command runs the headless server
CMD ["opencode", "serve", "--hostname", "127.0.0.1", "--port", "4096"]

# Health check endpoint is provided by opencode serve command
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://127.0.0.1:4096/health || exit 1
