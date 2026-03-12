# TODO: Minimal c-opencode Refactoring

## Overview
Simplify c-opencode to only 3 essential commands: default (attach TUI), web (show URL), and help. All other commands removed in favor of direct Docker usage or pass-through to opencode.

---

## User Requirements (Final)

### Commands to Implement
- **`c-opencode`** (no args) → Start server if needed, run `opencode attach <server_url>` in terminal (TUI)
- **`c-opencode web`** → Start server if needed, print server URL (do NOT open browser)
- **`c-opencode help`** → Show help message

### Pass-Through Behavior
- **`c-opencode <any_args>`** → `opencode <any_args> --attach <server_url> --dir /workspace/project`
- All opencode commands automatically handled via pass-through:
  - `c-opencode run "test"` → `opencode run "test" --attach <url> --dir /workspace/project`
  - `c-opencode session list` → `opencode session list --attach <url> --dir /workspace/project`
  - `c-opencode stats` → `opencode stats --attach <url> --dir /workspace/project`

### Commands to Remove (use Docker directly instead)
- `start` - no longer a separate command
- `stop` - use `docker stop`
- `restart` - use `docker restart`
- `status` - use `docker ps`
- `logs` - use `docker logs`
- `list` - use `docker ps -a`
- `clean` / `clean --all` - use `docker rm`
- `attach` - becomes default behavior
- `worktree` - removed entirely
- `list-sessions` - use `c-opencode session list` pass-through

---

## Implementation Plan

### Phase 1: Remove Command Functions

**Delete from c-opencode.sh (lines):**
- `cmd_start()` - 266-354
- `cmd_stop()` - 356-369
- `cmd_restart()` - 371-374
- `cmd_attach()` - 435-470
- `cmd_status()` - 376-420
- `cmd_logs()` - 422-433
- `cmd_list()` - 500-532
- `cmd_list_sessions()` - 472-498
- `cmd_clean()` - 626-713
- `cmd_worktree()` - 534-591
- `cmd_worktree_remove()` - 593-624

---

### Phase 2: Remove Helper Functions

**Delete from c-opencode.sh (lines):**
- `parse_args()` - 164-195 (no port/public args needed)
- `parse_global_flags()` - 197-215 (no --worktree needed)
- `get_worktree_hash()` - 49-53
- `get_worktree_path()` - 55-58
- `ensure_worktree()` - 236-260
- `build_docker_ports()` - 225-234 (only default port 4096)
- `get_bind_host()` - 217-223 (always 127.0.0.1)

---

### Phase 3: Remove Constants

**Delete from c-opencode.sh:**
- Line 16: `WORKTREE_DIR=".git/worktrees"`
- Line 18: `ADDITIONAL_PORTS=()`
- Line 19: `IS_PUBLIC=false`
- Line 20: `USE_WORKTREE=false`

**Keep:**
- `SERVER_HOST="0.0.0.0"` (used for container labels)
- `SERVER_PORT=4096`
- `CONTAINER_LABEL="opencode.managed=true"`

---

### Phase 4: Add cmd_web()

**Add new function:**
```bash
cmd_web() {
    check_docker
    ensure_docker_image
    
    local container_name=$(get_container_name)
    local port=$(get_container_port "$container_name")
    
    if [ -z "$port" ]; then
        echo "Server not running. Starting..."
        docker run -d \
            --name "$container_name" \
            --label "${CONTAINER_LABEL}" \
            -p 127.0.0.1::${SERVER_PORT} \
            -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
            -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
            -v "${HOME}/.local/state:/home/node/.local/state:rw" \
            -v "$(pwd):/workspace/project:rw" \
            -w /workspace/project \
            opencode:latest
        
        wait_for_container_ready "$container_name"
        port=$(get_container_port "$container_name")
    fi
    
    echo "http://127.0.0.1:${port}"
}
```

---

### Phase 5: Rewrite cmd_help()

```bash
cmd_help() {
    echo "OpenCode Local Wrapper"
    echo ""
    echo "Usage: c-opencode [command] [args]"
    echo ""
    echo "Commands:"
    echo "  (no args)    Start server and attach to OpenCode TUI"
    echo "  web          Show server URL"
    echo "  help         Show this help message"
    echo ""
    echo "Pass-through:"
    echo "  Any other arguments are passed to opencode with --attach flag."
    echo "  Examples:"
    echo "    c-opencode run 'add feature'"
    echo "    c-opencode session list"
    echo "    c-opencode stats"
    echo "    c-opencode models"
    echo ""
    echo "Container Management (use Docker directly):"
    echo "  docker ps                          # List running containers"
    echo "  docker logs <container>            # Show logs"
    echo "  docker stop <container>            # Stop container"
    echo "  docker rm <container>              # Remove container"
}
```

---

### Phase 6: Rewrite main()

```bash
main() {
    local command="${1:-}"
    
    case "$command" in
        "")
            # Default: start server if needed and attach TUI
            check_docker
            ensure_docker_image
            
            local container_name=$(get_container_name)
            local port=$(get_container_port "$container_name")
            
            if [ -z "$port" ]; then
                echo "Server not running. Starting..."
                docker run -d \
                    --name "$container_name" \
                    --label "${CONTAINER_LABEL}" \
                    -p 127.0.0.1::${SERVER_PORT} \
                    -v "${HOME}/.config/opencode:/home/node/.config/opencode:ro" \
                    -v "${HOME}/.local/share/opencode:/home/node/.local/share/opencode:rw" \
                    -v "${HOME}/.local/state:/home/node/.local/state:rw" \
                    -v "$(pwd):/workspace/project:rw" \
                    -w /workspace/project \
                    opencode:latest
                
                wait_for_container_ready "$container_name"
                port=$(get_container_port "$container_name)"
            fi
            
            local server_url="http://127.0.0.1:${port}"
            opencode attach "$server_url" --dir /workspace/project
            ;;
        web)
            cmd_web
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            # Pass through to opencode with --attach flag
            check_docker
            local container_name=$(get_container_name)
            local port=$(get_container_port "$container_name")
            
            if [ -z "$port" ]; then
                echo "Error: Server not running. Run 'c-opencode' to start."
                exit 1
            fi
            
            local server_url="http://127.0.0.1:${port}"
            opencode "$@" --attach "$server_url" --dir /workspace/project
            ;;
    esac
}
```

---

### Phase 7: Update Tests

**Remove tests (approx 20 tests):**
- All removed command tests (start, stop, restart, attach, status, logs, list, list-sessions, clean, worktree)
- All removed helper function tests (parse_args, build_docker_ports, get_bind_host, worktree functions)

**Keep tests:**
- Core helper functions (get_container_hash, get_container_name)
- check_docker, check_server
- cmd_help
- main function dispatch

**Add tests:**
- Default behavior (no args)
- `web` command
- Pass-through to opencode

**Remove test setup variables:**
- `ADDITIONAL_PORTS`, `IS_PUBLIC`, `USE_WORKTREE`, `WORKTREE_DIR`

---

### Phase 8: Update Documentation

**README.md changes:**
- Quick Start: `c-opencode` (no start command)
- Remove command table entries for: start, stop, restart, attach, status, logs, list, worktree, clean
- Add entries for: (no args), web
- Add "Pass-through" section with examples
- Update all examples
- Add "Container Management" section referencing Docker commands

**AGENTS.md changes:**
- Remove all references to removed commands
- Update "Build, Lint, and Test Commands" section
- Update "Naming Conventions" section (remove worktree)
- Simplify "Important Notes" section

---

### Phase 9: Remove Node.js Scripts

**Delete:**
- `scripts/opencode-list-sessions.js`
- `scripts/opencode-run.js`

These are no longer needed - pass-through handles all use cases.

---

## Final Script Structure

**Functions remaining (~200 lines, down from 806):**
- Helper functions: get_container_hash, get_container_name, check_docker, ensure_docker_image, wait_for_container_ready, get_container_port, get_container_by_path_label, check_server
- Command functions: cmd_web, cmd_help
- Main: main()

**Removed:**
- 11 command functions
- 8 helper functions
- 4 constants

---

## Validation Checklist

After implementation:
- [ ] Run `c-opencode` (no args) - starts server and attaches TUI
- [ ] Run `c-opencode web` - prints server URL
- [ ] Run `c-opencode help` - shows help
- [ ] Run `c-opencode run "test"` - passes through correctly
- [ ] Run `c-opencode session list` - lists sessions
- [ ] Run `c-opencode stats` - shows stats
- [ ] Run `c-opencode models` - lists models
- [ ] All tests pass: `bats tests/c-opencode.bats`
- [ ] README.md updated correctly
- [ ] AGENTS.md updated correctly
- [ ] Node.js scripts removed

---

## Files to Modify

1. **c-opencode.sh** - Remove ~600 lines, add ~50 lines (net -550 lines)
2. **tests/c-opencode.bats** - Remove ~20 tests, add ~3 tests
3. **README.md** - Update documentation
4. **AGENTS.md** - Update documentation

## Files to Remove

1. **scripts/opencode-list-sessions.js**
2. **scripts/opencode-run.js**

---

## Implementation Order

1. Remove obsolete functions from c-opencode.sh
2. Remove obsolete helper functions and constants
3. Add cmd_web() function
4. Rewrite cmd_help()
5. Rewrite main()
6. Update tests
7. Update documentation
8. Remove Node.js scripts
9. Run tests and validate

---

## Open Questions

None - all requirements clarified.
