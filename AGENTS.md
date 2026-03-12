# AGENTS.md - Developer Guide for AI Agents

This file contains guidelines and instructions for AI agents working in this repository.

---

## Project Overview

This is the OpenCode Docker Setup - a containerized environment for the OpenCode AI coding agent with server/client architecture and multi-project support.

### Key Files

| File | Description |
|------|-------------|
| `c-opencode.sh` | Main bash wrapper script (entry point) |
| `tests/c-opencode.bats` | BATS test suite |
| `Dockerfile` | Docker image definition |

---

## Build, Lint, and Test Commands

### Running Tests

```bash
# Run all tests
bats tests/c-opencode.bats

# Run a single test
bats tests/c-opencode.bats -f "test name"
```

### Docker Commands

```bash
# Build Docker image
docker build -t opencode:latest .

# Run container (manual)
docker run -d -p 4096:4096 opencode:latest
```

---

## Code Style Guidelines

### Bash Script (c-opencode.sh)

- Use `#!/bin/bash` shebang with `set -e`
- Use 4-space indentation
- Constants: UPPER_SNAKE_CASE (e.g., `SERVER_HOST`)
- Local variables: snake_case with `local` keyword
- Functions: snake_case, command functions prefixed with `cmd_`

### Functions

```bash
get_container_hash() {
    local project_path
    project_path=$(cd "$PWD" && pwd)
    echo "$project_path" | md5sum | cut -c1-16
}

cmd_start() {
    check_docker
    # ...
}
```

### Conditionals

```bash
# String comparisons use [[ ]]
if [ "$status" = "running" ]; then
    # ...
fi

# Regex uses [[ =~ ]]
[[ "$result" =~ ^opencode-[a-f0-9]{16}$ ]]
```

### Error Handling

- Use `set -e` at script start
- Check return codes explicitly for Docker commands
- Use `|| true` for commands that may fail gracefully

---

## JavaScript (scripts/*.js)

- ES6+ syntax (const/let, arrow functions)
- 2-space indentation
- Use `require()` for Node.js built-ins

---

## Dockerfile

- Use official base images with specific tags
- Chain RUN commands to minimize layers
- Use `--no-install-recommends` for apt
- Clean up: `rm -rf /var/lib/apt/lists/*`

---

## Testing Guidelines

### BATS Test Structure

```bash
setup() {
    export VARIABLE=value
    export BATS_TEST=true
    source "$SCRIPT"
}

@test "descriptive test name" {
    result=$(some_function)
    [ "$result" = "expected" ]
    [[ "$result" =~ regex_pattern ]]
}
```

- All tests must pass before committing
- Use descriptive test names
- Test one thing per test

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Script functions | snake_case | `get_container_hash` |
| Command functions | cmd_* prefix | `cmd_start` |
| Constants | UPPER_SNAKE_CASE | `SERVER_HOST` |
| Local variables | snake_case | `container_name` |

---

## Important Notes

- Each project directory gets a unique container (hash-based naming)
- Default command starts server and attaches TUI
- Attach uses `/workspace/project` as working directory
- Commands: `(no args)`, `web`, `help` (all other args passed through to opencode)

---

## Dependencies

- **BATS**: `brew install bats-core`
- **Docker**: Container runtime
- **jq**: JSON processing (in container)
- **md5sum**: Hash generation (macOS: `brew install coreutils`)
