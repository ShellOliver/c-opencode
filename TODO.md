# Custom Build Script Implementation - COMPLETED ✅

## Overview
Enable custom Docker image builds via `.opencode/c-opencode-image.sh` script that runs inside the container during build time.

## Implementation Status

### ✅ Completed (After Review Fixes)

1. **Folder Name Sanitization**
   - ✅ Convert folder name to valid Docker image name
   - ✅ Replace spaces/special characters with hyphens
   - ✅ Remove consecutive hyphens
   - ✅ Ensure lowercase
   - ✅ POSIX-compliant using `printf` instead of `echo`
   - ✅ Handle empty strings (return "default")

2. **Helper Functions Added**
   - ✅ `sanitize_image_name()` - Sanitize folder name for Docker (POSIX-compliant)
   - ✅ `has_custom_build_script()` - Check if `.opencode/c-opencode-image.sh` exists
   - ✅ `get_custom_image_name()` - Generate custom image name based on folder
   - ✅ `ensure_custom_image()` - Build custom image if needed
   - ✅ `build_custom_image()` - Execute Docker build with custom script (secure)
   - ✅ `get_target_image()` - Return appropriate image (custom or default)
   - ✅ `force_rebuild_image()` - Force rebuild custom image (with Docker check)

3. **Container Launch Functions Modified**
   - ✅ `cmd_web()` - Now uses `get_target_image()` instead of hardcoded `opencode:latest`
   - ✅ `main()` (default command) - Now uses `get_target_image()` instead of hardcoded `opencode:latest`

4. **New Commands Added**
   - ✅ `--rebuild-image` flag to force rebuild custom images
   - ✅ Flag handled in main() function

5. **Help Documentation Updated**
   - ✅ "Custom Build Scripts" section added to `cmd_help()`
   - ✅ Usage and examples documented

6. **Tests Written**
   - ✅ Test folder name sanitization (special characters, edge cases, empty strings)
   - ✅ Test custom image name generation
   - ✅ Test custom build script detection
   - ✅ Test target image selection logic
   - ✅ All 14 tests passing

7. **README.md Updated**
   - ✅ "Custom Build Scripts" section added
   - ✅ Example scripts provided (Node.js, Python)
   - ✅ Rebuild workflow documented
   - ✅ Security note added (runs as node user)
   - ✅ Manual rebuild requirement documented

## Review Fixes Applied (High Priority)

### Issue 2: Temporary File Cleanup
- ✅ Added `trap 'rm -f "$tmp_dockerfile"' EXIT` in `build_custom_image()`
- Ensures cleanup even if build is interrupted (Ctrl+C)

### Issue 3: Security - Run as Non-Root
- ✅ Added `USER node` in generated Dockerfile
- Custom build script now runs as `node` user instead of `root`

### Issue 5: Docker Check Missing
- ✅ Added `check_docker()` call in `force_rebuild_image()`
- Consistent with other command functions

### Issue 9: POSIX Compliance & Empty String Handling
- ✅ Replaced `echo` with `printf '%s'` for better POSIX compliance
- ✅ Added validation for empty strings (returns "default")
- ✅ Added test case for empty string handling

## Usage Examples

### Node.js Project
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
c-opencode
```

### Python Project
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
c-opencode
```

### Rebuilding Custom Images
```bash
c-opencode --rebuild-image
```

## Security Considerations

- Custom build script runs as `node` user inside container (not root)
- Script runs during build time, not runtime
- No host file access during build
- Changes tracked in git via `.opencode/c-opencode-image.sh`

## Files Modified

- `c-opencode.sh` - Added 7 functions, modified 2 functions, updated help, applied 4 security/robustness fixes
- `tests/c-opencode.bats` - Added 6 new tests (total: 14 tests, all passing)
- `README.md` - Added "Custom Build Scripts" section with security notes
- `TODO.md` - Marked implementation as complete
