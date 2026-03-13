# Plan: Container Configuration with container.yaml

## Overview
Add support for `container.yaml` configuration file to specify port mappings and other container options. This allows users to expose custom ports from services running inside the container without editing the Dockerfile.

**Decision: Use bundled yq binary for YAML parsing**

## User Requirements
- **Dynamic/unknown ports**: Services may run on different ports
- **Config file approach**: Use `container.yaml` with ports list option
- **Flexible port mapping**: Mapping defined in YAML file (host:container format)
- **No Dockerfile editing**: Dockerfile is part of npm package, not editable
- **No custom script editing**: Custom scripts should not need modification
- **Zero runtime dependencies**: Bundle yq binary with npm package

## Proposed container.yaml Format

### Basic Format
```yaml
name: my-project
ports:
  - "3000:3000"
  - "8080:8080"
  - "127.0.0.1:5000:5000"
```

### With Optional Features
```yaml
name: my-project
ports:
  - "3000:3000"
  - "8080:8080"
  - "127.0.0.1:5000:5000"

# Future extensions (optional)
env:
  NODE_ENV: development
  DEBUG: "true"

# Future extensions (optional)
labels:
  custom.label: "value"
```

## Implementation Plan

### Phase 0: Bundle yq Binary

#### 0.1 Package Structure
```
├── bin/
│   ├── yq_linux_amd64
│   ├── yq_linux_arm64
│   ├── yq_darwin_amd64
│   ├── yq_darwin_arm64
│   └── yq_windows_amd64.exe
├── c-opencode.sh
├── install.sh
├── uninstall.sh
└── README.md
```

#### 0.2 Download yq Binaries
Create script to download yq v4.52.4 binaries:
```bash
#!/bin/bash
# download-yq.sh

VERSION=v4.52.4
mkdir -p bin

wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_amd64 -O bin/yq_linux_amd64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_arm64 -O bin/yq_linux_arm64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_darwin_amd64 -O bin/yq_darwin_amd64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_darwin_arm64 -O bin/yq_darwin_arm64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_windows_amd64.exe -O bin/yq_windows_amd64.exe

chmod +x bin/yq_*
```

#### 0.3 Update install.sh
```bash
#!/bin/bash
# Detect platform
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Map architectures
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    i386|i686) ARCH="386" ;;
    *) ARCH="amd64" ;;  # fallback
esac

# Determine yq binary path
YQ_BINARY="${SCRIPT_DIR}/bin/yq_${OS}_${ARCH}"

# Check if yq exists
if [ ! -f "$YQ_BINARY" ]; then
    echo "Error: yq binary not found for your platform (${OS}_${ARCH})"
    echo "Please report this issue."
    exit 1
fi

# Install c-opencode and yq
# ... existing c-opencode installation code ...

# Install yq to user's PATH
YQ_INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$YQ_INSTALL_DIR"
cp "$YQ_BINARY" "$YQ_INSTALL_DIR/yq"
chmod +x "$YQ_INSTALL_DIR/yq"

echo "yq installed to $YQ_INSTALL_DIR/yq"
```

### Phase 1: YAML Parsing with yq

#### 1.1 Get yq Binary Path
```bash
get_yq_binary() {
    local script_dir="${SCRIPT_DIR}"

    # First try: Installed in ~/.local/bin (from install.sh)
    if [ -x "$HOME/.local/bin/yq" ]; then
        echo "$HOME/.local/bin/yq"
        return
    fi

    # Fallback: Use bundled binary
    local arch
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        i386|i686) arch="386" ;;
        *) arch="amd64" ;;
    esac

    local bundled_yq="${script_dir}/bin/yq_${os}_${arch}"

    if [ -f "$bundled_yq" ]; then
        echo "$bundled_yq"
        return
    fi

    echo ""
}
```

#### 1.2 Check yq Availability
```bash
has_yq() {
    local yq_bin
    yq_bin=$(get_yq_binary)
    [ -n "$yq_bin" ] && [ -x "$yq_bin" ]
}
```

#### 1.3 Parse Ports from YAML
```bash
get_container_ports() {
    local config_file=".opencode/container.yaml"

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    if ! has_yq; then
        echo "Warning: yq not found. Cannot parse container.yaml"
        echo "Please run install.sh to set up yq."
        return 0
    fi

    local yq_bin
    yq_bin=$(get_yq_binary)

    # Parse ports array from YAML
    "$yq_bin" eval '.ports[]' "$config_file" 2>/dev/null
}
```

### Phase 2: Port Mapping Generation

#### 2.1 Generate Docker Port Flags
```bash
get_port_flags() {
    local ports=$1
    local flags=""

    if [ -n "$ports" ]; then
        while IFS= read -r port; do
            if [ -n "$port" ]; then
                flags="${flags} -p ${port}"
            fi
        done <<< "$ports"
    fi

    # Always add opencode port
    flags="${flags} -p 127.0.0.1::${SERVER_PORT}"

    echo "$flags"
}
```

### Phase 3: Update Container Launch Functions

#### 3.1 Modify `cmd_web()`
Add port configuration:
```bash
cmd_web() {
    check_docker
    ensure_docker_image

    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    local target_image
    target_image=$(get_target_image)

    if [ -z "$port" ]; then
        echo "Server not running. Starting..."

        # Get custom ports from container.yaml
        local custom_ports
        custom_ports=$(get_container_ports)

        # Generate port flags
        local port_flags
        port_flags=$(get_port_flags "$custom_ports")

        if [ -n "$custom_ports" ]; then
            echo "Exposing additional ports: $custom_ports"
        fi

        docker run -d \
            --name "$container_name" \
            --label "${CONTAINER_LABEL}" \
            ${port_flags} \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "$(pwd):/workspace/project:rw" \
            -w /workspace/project \
            "$target_image"

        wait_for_container_ready "$container_name"
        port=$(get_container_port "$container_name")
    fi

    echo "http://127.0.0.1:${port}"
}
```

#### 3.2 Modify `main()` - Default Command
Same changes as cmd_web() to add port_flags.

### Phase 4: Documentation & Examples

#### 4.1 Create Example container.yaml
```yaml
# .opencode/container.yaml.example
# Copy this file to .opencode/container.yaml and configure your ports

# Container name (optional)
name: my-project

# Port mappings (host:container format)
# Examples:
#   "3000"              - Expose port 3000 on random host port
#   "3000:3000"          - Map host port 3000 to container port 3000
#   "8080:3000"          - Map host port 8080 to container port 3000
#   "127.0.0.1:5000:5000" - Bind to localhost only
ports:
  - "3000:3000"
  - "8080:8080"
  - "127.0.0.1:5000:5000"
```

#### 4.2 Update `cmd_help()`
```bash
echo ""
echo "Container Configuration:"
echo "  Create .opencode/container.yaml to configure ports and options."
echo "  Example:"
echo "    ports:"
echo "      - \"3000:3000\""
echo "      - \"8080:8080\""
echo ""
echo "  See README.md for full documentation and examples."
```

### Phase 5: Testing

#### 5.1 Unit Tests
```bash
@test "get_yq_binary returns installed path first"
@test "has_yq returns true when yq exists"
@test "get_container_ports parses YAML correctly"
@test "get_port_flags generates correct Docker flags"
@test "get_port_flags includes opencode port"
```

#### 5.2 Integration Tests (if possible)
- Test with actual container.yaml file
- Test with multiple ports
- Test with missing config (fallback)

## File Changes Required

### New Files
- `bin/yq_linux_amd64` - Downloaded yq binary
- `bin/yq_linux_arm64` - Downloaded yq binary
- `bin/yq_darwin_amd64` - Downloaded yq binary
- `bin/yq_darwin_arm64` - Downloaded yq binary
- `bin/yq_windows_amd64.exe` - Downloaded yq binary
- `download-yq.sh` - Script to download yq binaries
- `.opencode/container.yaml.example` - Example configuration

### Modified Files
- `c-opencode.sh` - Add yq functions, update container launch
- `install.sh` - Install yq binary to user's PATH
- `tests/c-opencode.bats` - Add tests for port configuration
- `README.md` - Add container.yaml documentation

## Implementation Order

1. ✅ Create bin/ directory structure
2. ✅ Create download-yq.sh script
3. ✅ Download yq binaries (run download-yq.sh)
4. ✅ Update install.sh to install yq
5. ✅ Add yq detection functions to c-opencode.sh
6. ✅ Add port parsing functions to c-opencode.sh
7. ✅ Add port flag generation to c-opencode.sh
8. ✅ Modify cmd_web() to use port flags
9. ✅ Modify main() to use port flags
10. ✅ Update help documentation
11. ✅ Write tests
12. ✅ Update README with examples
13. ✅ Create example container.yaml

## Edge Cases & Considerations

### yq Binary Not Available
- **Problem**: Bundled binary doesn't match platform
- **Solution**: Clear error message, ask user to report issue
- **Fallback**: Attempt to use system yq if installed

### Missing container.yaml
- **Solution**: Continue with default behavior (only opencode port)
- **Implementation**: Check file existence, return 0 if missing

### Invalid YAML
- **Problem**: container.yaml has syntax errors
- **Solution**: yq will return error, show warning, continue without custom ports
- **Implementation**: Suppress yq errors, handle gracefully

### Container Already Running
- **Problem**: User modifies container.yaml while container is running
- **Solution**: Show message that restart is required
- **Future enhancement**: Auto-restart on config change

### Port Conflicts
- **Problem**: Host port already in use
- **Solution**: Let Docker provide error messages
- **Future enhancement**: Pre-validate ports before container start

### Backward Compatibility
- **Problem**: Existing users don't have container.yaml
- **Solution**: Default behavior unchanged, only add ports if config exists
- **Implementation**: Check file existence before parsing

## Benefits

✅ **Zero runtime dependencies**: yq bundled with npm package
✅ **Simple parsing**: Single command `yq eval '.ports[]'`
✅ **Cross-platform**: Binaries for all major platforms
✅ **User-friendly**: Declarative configuration, no code changes
✅ **Git-tracked**: container.yaml can be version controlled
✅ **Backward Compatible**: Works without config file
✅ **Extensible**: Easy to add env vars, labels, etc. later

## Package Size Impact

| Platform | Binary Size | Impact |
|----------|-------------|---------|
| Linux AMD64 | ~4 MB | +4 MB |
| Linux ARM64 | ~3.7 MB | +3.7 MB |
| macOS AMD64 | ~4 MB | +4 MB |
| macOS ARM64 | ~3.7 MB | +3.7 MB |
| Windows | ~4 MB | +4 MB |

**Total npm package size increase**: ~16 MB (4 platforms × ~4 MB)

**Mitigation**:
- Only needed for port configuration feature
- User can opt-out (don't create container.yaml)
- Future: Could be optional download on first use


### Phase 2: Port Mapping Generation

#### 2.1 Generate Docker Port Flags
```bash
get_port_flags() {
    local ports=$1
    local flags=""

    if [ -n "$ports" ]; then
        while IFS= read -r port; do
            if [ -n "$port" ]; then
                flags="${flags} -p ${port}"
            fi
        done <<< "$ports"
    fi

    # Always add opencode port
    flags="${flags} -p 127.0.0.1::${SERVER_PORT}"

    echo "$flags"
}
```

### Phase 3: Update Container Launch Functions

#### 3.1 Modify `cmd_web()`
Current:
```bash
docker run -d \
    --name "$container_name" \
    --label "${CONTAINER_LABEL}" \
    -p 127.0.0.1::${SERVER_PORT} \
    -v ... \
    "$target_image"
```

New:
```bash
cmd_web() {
    check_docker
    ensure_docker_image

    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    local target_image
    target_image=$(get_target_image)

    if [ -z "$port" ]; then
        echo "Server not running. Starting..."

        # Get custom ports from container.yaml
        local custom_ports
        custom_ports=$(get_container_ports)

        # Generate port flags
        local port_flags
        port_flags=$(get_port_flags "$custom_ports")

        if [ -n "$custom_ports" ]; then
            echo "Exposing additional ports: $custom_ports"
        fi

        docker run -d \
            --name "$container_name" \
            --label "${CONTAINER_LABEL}" \
            ${port_flags} \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "$(pwd):/workspace/project:rw" \
            -w /workspace/project \
            "$target_image"

        wait_for_container_ready "$container_name"
        port=$(get_container_port "$container_name")
    fi

    echo "http://127.0.0.1:${port}"
}
```

#### 3.2 Modify `main()` - Default Command
Same changes as cmd_web() to add port_flags.

### Phase 4: Validation & Error Handling

#### 4.1 Port Format Validation
```bash
validate_port_mapping() {
    local port_mapping=$1

    # Valid formats:
    # 3000                    (container port only)
    # 3000:3000              (host:container, same port)
    # 8080:3000              (host:container, different ports)
    # 127.0.0.1:3000:3000   (host IP:host port:container port)

    if [[ ! "$port_mapping" =~ ^([0-9]+:[0-9]+|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+:[0-9]+)$ ]]; then
        echo "Error: Invalid port mapping format: $port_mapping"
        echo "Valid formats: 3000:3000, 8080:3000, 127.0.0.1:3000:3000"
        return 1
    fi

    return 0
}
```

#### 4.2 Port Conflict Detection (Optional)
```bash
check_port_available() {
    local port=$1

    if lsof -i :$port &> /dev/null; then
        echo "Warning: Port $port is already in use on host"
        return 1
    fi
    return 0
}
```

### Phase 5: Documentation

#### 5.1 Update `cmd_help()`
```bash
echo ""
echo "Container Configuration:"
echo "  Create .opencode/container.yaml to configure ports and options."
echo "  Example:"
echo "    ports:"
echo "      - \"3000:3000\""
echo "      - \"8080:8080\""
echo ""
echo "  Requirements: yq (recommended), python3+PyYAML, or basic grep support"
```

#### 5.2 Update README.md
Add comprehensive section on container.yaml usage with examples.

### Phase 6: Testing

#### 6.1 Unit Tests
```bash
@test "parse_yaml_ports_simple extracts ports from YAML"
@test "get_port_flags generates correct Docker flags"
@test "validate_port_mapping accepts valid formats"
@test "validate_port_mapping rejects invalid formats"
```

#### 6.2 Integration Tests
- Test with actual container.yaml file
- Test with multiple ports
- Test with missing config (fallback)
- Test with invalid YAML (error handling)

## File Changes Required

### c-opencode.sh
Add functions:
- `has_yaml_parser()` - Check for YAML parsing capability
- `parse_yaml_ports_yq()` - Parse with yq
- `parse_yaml_ports_simple()` - Fallback parsing
- `parse_yaml_ports_python()` - Python fallback
- `get_container_ports()` - Unified port parsing
- `get_port_flags()` - Generate Docker -p flags
- `validate_port_mapping()` - Validate port format

Modify functions:
- `cmd_web()` - Add port flags from config
- `main()` - Add port flags from config
- `cmd_help()` - Add documentation

### tests/c-opencode.bats
Add 5+ new tests for port configuration parsing.

### README.md
Add "Container Configuration" section with:
- container.yaml format specification
- YAML parser requirements
- Examples for different scenarios
- Troubleshooting tips

### Example Files (for documentation)
Create `.opencode/container.yaml.example`:
```yaml
# Example container configuration
# Place this in your project's .opencode/container.yaml

# Container name (optional)
name: my-project

# Port mappings (host:container format)
ports:
  - "3000:3000"
  - "8080:8080"
  - "127.0.0.1:5000:5000"

# Environment variables (optional, future)
# env:
#   NODE_ENV: development
#   DEBUG: "true"
```

## Implementation Order

1. ✅ Add YAML parser detection
2. ✅ Add parsing functions (yq, Python, simple fallback)
3. ✅ Add unified get_container_ports() function
4. ✅ Add port flag generation
5. ✅ Add port validation
6. ✅ Modify cmd_web() to use port flags
7. ✅ Modify main() to use port flags
8. ✅ Update help documentation
9. ✅ Write tests
10. ✅ Update README with examples
11. ✅ Create example container.yaml file

## Edge Cases & Considerations

### YAML Parser Availability
- **Problem**: User may not have yq, python+PyYAML, or ruby
- **Solution**: Provide clear error message with installation instructions
- **Fallback**: Simple grep/sed parsing for basic YAML (works for simple port lists)

### Port Conflicts
- **Problem**: Host port already in use
- **Solution**: Warning message, let Docker handle the error
- **Future enhancement**: Auto-detect and suggest alternative ports

### Invalid YAML
- **Problem**: container.yaml has syntax errors
- **Solution**: Graceful degradation, show warning, continue without custom ports

### Container Already Running
- **Problem**: User modifies container.yaml while container is running
- **Solution**: Show message that restart is required
- **Future enhancement**: Auto-restart on config change

### Backward Compatibility
- **Problem**: Existing users don't have container.yaml
- **Solution**: Default behavior unchanged, only add ports if config exists

## Future Enhancements (Out of Scope)

1. **Environment Variables**: Parse `env:` section from container.yaml
2. **Labels**: Parse `labels:` section for container labels
3. **Auto-detection**: Automatically expose ports based on package.json scripts
4. **Hot-reload**: Restart container when container.yaml changes
5. **Network Configuration**: Custom network settings
6. **Resource Limits**: CPU/memory limits in container.yaml
7. **Volume Mappings**: Additional volume mounts in container.yaml

## Benefits

✅ **Flexible**: Supports any port configuration via YAML
✅ **User-friendly**: Declarative configuration, no code changes
✅ **Git-tracked**: container.yaml can be version controlled
✅ **Backward Compatible**: Works without config file
✅ **Extensible**: Easy to add more options (env, labels, etc.)
✅ **Multiple Parsers**: Works with yq, Python, or simple grep

## Risks & Mitigations

### Risk: YAML Parser Not Available
- **Mitigation**: Provide multiple parsing strategies (yq, Python, grep)
- **Mitigation**: Clear error messages with installation instructions
- **Mitigation**: Fallback to simple grep for basic YAML

### Risk: Port Conflicts
- **Mitigation**: Let Docker provide error messages
- **Mitigation**: Future: pre-validate ports before container start

### Risk: Breaking Changes
- **Mitigation**: Feature is opt-in via container.yaml
- **Mitigation**: Backward compatible (no config = no changes)
