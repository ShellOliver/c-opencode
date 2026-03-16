#!/bin/bash
set -e

# This script runs inside the container during build
# It sets up a minimal HTTP server on port 3011

echo "Setting up minimal test server on port 3011..."

# Create a simple HTML file to serve
mkdir -p /tmp/test-server
cat > /tmp/test-server/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Test Server</title>
</head>
<body>
    <h1>OpenCode Test Server</h1>
    <p>Server is running on port 3011</p>
    <p>This is a custom build script test.</p>
    <p>Port: 3011 (configured via container.yaml)</p>
</body>
</html>
EOF

# Create a simple Python HTTP server script
cat > /tmp/test-server/server.py <<'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 3011
DIRECTORY = "/tmp/test-server"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def run():
    print(f"Test server listening on port {PORT}")
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run()
EOF

chmod +x /tmp/test-server/server.py

# Create entrypoint to start both servers
cat > /tmp/test-entrypoint.sh <<'EOF'
#!/bin/bash
set -e

# Start test server in background
cd /tmp/test-server
python3 server.py &
TEST_SERVER_PID=$!

# Wait for test server to start
sleep 2

# Check if test server is running
if ! kill -0 $TEST_SERVER_PID 2>/dev/null; then
    echo "Error: Test server failed to start"
    exit 1
fi

echo "Test server started on port 3011 (PID: $TEST_SERVER_PID)"

# Start main opencode server
exec opencode serve --mdns --port 4096
EOF

chmod +x /tmp/test-entrypoint.sh

echo "Test server configured on port 3011"
echo "Server will be accessible at http://localhost:3011"
echo "Server will be accessible at http://localhost:3011"
