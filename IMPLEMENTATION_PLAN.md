# Implementation Plan: Custom Build Script Support

## Overview
Enable custom Docker image builds via `.opencode/c-opencode-image.sh` script that runs inside the container during build time.

## Requirements (Based on User Input)
- **Script execution**: Run inside container during build (like `RUN apt-get && npm install`)
- **Image naming**: Use root folder name (e.g., `opencode-myproject:latest`)
- **Change detection**: Only rebuild when image is missing (not on script changes)

## Implementation Strategy

### 1. Folder Name Sanitization
**Function: `sanitize_image_name()`**
- Convert to lowercase
- Replace spaces/special characters with hyphens
- Remove consecutive hyphens
- Trim leading/trailing hyphens
- Ensure valid Docker image name format

**Examples:**
- `My Project` → `opencode-my-project`
- `Project_v2.0` → `opencode-project_v2-0`
- `test@dev#123` → `opencode-test-dev-123`

### 2. New Helper Functions

#### `has_custom_build_script()`
```bash
has_custom_build_script() {
    [ -f ".opencode/c-opencode-image.sh" ]
}
```

#### `get_custom_image_name()`
```bash
get_custom_image_name() {
    local project_name
    project_name=$(basename "$(pwd)")
    local sanitized
    sanitized=$(sanitize_image_name "$project_name")
    echo "opencode-${sanitized}:latest"
}
```

#### `ensure_custom_image()`
```bash
ensure_custom_image() {
    if ! has_custom_build_script; then
        return 0
    fi

    local image_name
    image_name=$(get_custom_image_name)

    if docker image inspect "$image_name" &> /dev/null; then
        return 0
    fi

    echo "Building custom image: $image_name"
    build_custom_image "$image_name"
}
```

#### `build_custom_image()`
```bash
build_custom_image() {
    local image_name=$1
    local tmp_dockerfile
    tmp_dockerfile=$(mktemp)

    # Generate temporary Dockerfile
    cat > "$tmp_dockerfile" <<EOF
FROM opencode:latest
COPY .opencode/c-opencode-image.sh /tmp/build-script.sh
RUN bash /tmp/build-script.sh
EOF

    # Build from temporary Dockerfile
    docker build -t "$image_name" -f "$tmp_dockerfile" "$(pwd)"
    local build_status=$?

    rm -f "$tmp_dockerfile"

    if [ $build_status -ne 0 ]; then
        echo "Error: Failed to build custom image"
        exit 1
    fi

    echo "Custom image built successfully: $image_name"
}
```

#### `get_target_image()`
```bash
get_target_image() {
    if has_custom_build_script; then
        ensure_custom_image
        get_custom_image_name
    else
        echo "opencode:latest"
    fi
}
```

### 3. Modify Container Launch Functions

#### Update `cmd_web()`
- Change `opencode:latest` to use `get_target_image`
- Keep all other logic the same

**Current (line 152):**
```bash
opencode:latest
```

**New:**
```bash
$(get_target_image)
```

#### Update `main()` - Default Command
- Change `opencode:latest` to use `get_target_image`
- Keep all other logic the same

**Current (line 213):**
```bash
opencode:latest
```

**New:**
```bash
$(get_target_image)
```

### 4. Update Help Documentation

#### `cmd_help()` Enhancements
Add section explaining custom build scripts:
```bash
echo ""
echo "Custom Build Scripts:"
echo "  Create .opencode/c-opencode-image.sh to customize the container image."
echo "  The script runs inside the container during build (e.g., npm install)."
echo "  Image name: opencode-<foldername>:latest"
echo "  Rebuild: c-opencode --rebuild-image"
```

### 5. Add New Commands

#### `--rebuild-image` Flag
Allow users to force rebuild the custom image:
```bash
if [ "$1" = "--rebuild-image" ]; then
    force_rebuild_image
    shift
fi
```

#### `force_rebuild_image()`
```bash
force_rebuild_image() {
    if ! has_custom_build_script; then
        echo "No custom build script found in .opencode/c-opencode-image.sh"
        exit 1
    fi

    local image_name
    image_name=$(get_custom_image_name)

    echo "Removing existing image: $image_name"
    docker image rm "$image_name" &> /dev/null || true

    echo "Rebuilding custom image..."
    build_custom_image "$image_name"
}
```

### 6. Implementation Order

1. ✅ Add folder name sanitization function
2. ✅ Add helper functions to detect and manage custom images
3. ✅ Modify container launch functions to use custom images
4. ✅ Add rebuild command
5. ✅ Update help documentation
6. ✅ Write tests
7. ✅ Update README with examples

## File Changes

### c-opencode.sh
- Add: `sanitize_image_name()`
- Add: `has_custom_build_script()`
- Add: `get_custom_image_name()`
- Add: `ensure_custom_image()`
- Add: `build_custom_image()`
- Add: `get_target_image()`
- Add: `force_rebuild_image()`
- Modify: `cmd_web()` line 152
- Modify: `main()` line 213
- Modify: `cmd_help()` add documentation

### tests/c-opencode.bats
Add tests:
- `test sanitize_image_name handles special characters`
- `test get_custom_image_name returns correct format`
- `test has_custom_build_script returns true when file exists`
- `test get_target_image returns custom image when script exists`
- `test get_target_image returns default when no script`

### README.md
Add section:
- "Custom Build Scripts"
- Examples of `.opencode/c-opencode-image.sh`
- How to rebuild custom images

## Example Custom Build Scripts

### Node.js Project (.opencode/c-opencode-image.sh)
```bash
#!/bin/bash
set -e

cd /workspace/project
npm install
npm run build
```

### Python Project (.opencode/c-opencode-image.sh)
```bash
#!/bin/bash
set -e

apt-get update && apt-get install -y python3-pip
cd /workspace/project
pip install -r requirements.txt
```

### Additional System Tools (.opencode/c-opencode-image.sh)
```bash
#!/bin/bash
set -e

apt-get update && apt-get install -y \
    postgresql-client \
    redis-tools \
    awscli
```

## Edge Cases & Error Handling

1. **Invalid folder name**: Sanitize to ensure valid Docker image name
2. **Build script failure**: Exit with error, don't use partial image
3. **Script permissions**: Check executable, warn if not
4. **Base image missing**: Call `ensure_docker_image()` first
5. **Custom image corrupted**: Allow rebuild via `--rebuild-image`

## Testing Strategy

1. **Unit tests**: Test individual functions (sanitize, name generation)
2. **Integration tests**: Test image building process
3. **End-to-end tests**: Test full workflow with real script
4. **Error tests**: Test build failures, invalid scripts

## Benefits

✅ Build-time optimization (scripts run once, not every container start)
✅ Reusable images across container restarts
✅ Fast container startup
✅ Project-specific customizations
✅ Git-trackable build scripts
✅ Clean separation between base and custom images

## Rollback Plan

If issues arise:
1. Fallback to `opencode:latest` if custom image build fails
2. Document `--rebuild-image` for manual recovery
3. Consider adding `--use-base-image` flag to force base image usage
