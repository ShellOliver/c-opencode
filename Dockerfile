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
WORKDIR /workspace

# Create non-root user for security
RUN groupadd -g 1000 opencode && \
    useradd -u 1000 -g opencode -d /workspace -s /bin/bash opencode && \
    chown -R opencode:opencode /workspace

# Switch to non-root user
USER opencode

# Set environment variables
ENV NODE_ENV=production
ENV PATH="/home/opencode/.local/bin:${PATH}"

# Expose the opencode server port
EXPOSE 4096

# Default command runs the headless server
CMD ["opencode", "serve", "--hostname", "127.0.0.1", "--port", "4096"]
