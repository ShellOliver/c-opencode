# syntax=docker/dockerfile:1

# Production image
FROM node:22-alpine

# Labels
LABEL maintainer="opencode"
LABEL description="Opencode AI coding agent container"

# Install any needed dependencies
RUN apk add --no-cache \
    git \
    bash

# Set working directory
WORKDIR /workspace

# Install opencode globally from npm
RUN npm install --global @opencode/agent

# Clean npm cache
RUN npm cache clean --force

# Create non-root user for security
RUN addgroup -g 1000 opencode && \
    adduser -u 1000 -G opencode -D -s /bin/bash opencode

# Change ownership of workspace
RUN chown -R opencode:opencode /workspace

# Switch to non-root user
USER opencode

# Set environment variables
ENV NODE_ENV=production
ENV PATH="/root/.npm-global/bin:${PATH}"

# Default command
CMD ["opencode"]
