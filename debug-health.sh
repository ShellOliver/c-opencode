#!/bin/bash

# Debug script to check opencode server health

echo "=== Debug Information ==="

echo "1. Port file content:"
cat .opencode-port
echo ""

echo "2. Docker port mapping:"
docker port opencode-server-opencode 2>/dev/null || echo "Container not found or no ports"

echo "3. Container status:"
docker ps --filter "name=opencode-server-opencode" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "4. Testing from HOST (should check port 4101):"
echo "   Testing: http://127.0.0.1:4101/health"
PORT=$(cat .opencode-port)
curl -v "http://127.0.0.1:${PORT}/health" 2>&1 | grep -E "(Connected|Empty reply|HTTP/)" | head -5

echo ""
echo "5. Testing from INSIDE container (port 4096):"
docker exec opencode-server-opencode curl -sI "http://127.0.0.1:4096/health" 2>&1 | grep -E "HTTP/|content-length"

echo ""
echo "6. Direct curl with %{http_code}:"
echo "   Result: $(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:4101/health')"

echo ""
echo "7. Check what the check_server function expects:"
echo "   It runs: curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:4101/health' | grep -q '200'"
echo "   But the actual response code is: $(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:4101/health')"
