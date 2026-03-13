#!/bin/bash
# Download yq binaries for all supported platforms

VERSION=v4.52.4
mkdir -p bin

echo "Downloading yq v${VERSION} binaries..."

# Linux AMD64
echo "Downloading yq_linux_amd64..."
curl -sL https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_amd64 -o bin/yq_linux_amd64
chmod +x bin/yq_linux_amd64

# Linux ARM64
echo "Downloading yq_linux_arm64..."
curl -sL https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_arm64 -o bin/yq_linux_arm64
chmod +x bin/yq_linux_arm64

# macOS AMD64
echo "Downloading yq_darwin_amd64..."
curl -sL https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_darwin_amd64 -o bin/yq_darwin_amd64
chmod +x bin/yq_darwin_amd64

# macOS ARM64
echo "Downloading yq_darwin_arm64..."
curl -sL https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_darwin_arm64 -o bin/yq_darwin_arm64
chmod +x bin/yq_darwin_arm64

# Windows AMD64
echo "Downloading yq_windows_amd64.exe..."
curl -sL https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_windows_amd64.exe -o bin/yq_windows_amd64.exe
chmod +x bin/yq_windows_amd64.exe

echo "All yq binaries downloaded successfully!"
ls -lh bin/
