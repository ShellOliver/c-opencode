#!/usr/bin/env bats

setup() {
    export ADDITIONAL_PORTS=()
    export IS_PUBLIC=false
    export USE_WORKTREE=false
    export REMAINING_ARGS=()
    export SERVER_HOST="0.0.0.0"
    export SERVER_PORT=4096
    export WORKTREE_DIR=".git/worktrees"
    export TESTDIR="$BATS_TEST_DIRNAME"
    export SCRIPT="$TESTDIR/../c-opencode.sh"
    export BATS_TEST=true

    source "$SCRIPT"
}

@test "get_container_hash returns 16 character hash" {
    result=$(get_container_hash)
    [ ${#result} -eq 16 ]
    [[ "$result" =~ ^[a-f0-9]+$ ]]
}

@test "get_container_name returns opencode-prefixed name" {
    result=$(get_container_name)
    [[ "$result" =~ ^opencode-[a-f0-9]{16}$ ]]
}

@test "get_worktree_hash returns 8 character hash" {
    result=$(get_worktree_hash)
    [ ${#result} -eq 8 ]
    [[ "$result" =~ ^[a-f0-9]+$ ]]
}

@test "get_worktree_path returns correct path" {
    result=$(get_worktree_path)
    [[ "$result" == ".git/worktrees/opencode-"* ]]
}

@test "get_bind_host returns 127.0.0.1 by default" {
    result=$(get_bind_host)
    [ "$result" = "127.0.0.1" ]
}

@test "get_bind_host returns 0.0.0.0 when public" {
    IS_PUBLIC=true result=$(get_bind_host)
    [ "$result" = "0.0.0.0" ]
}

@test "build_docker_ports returns default port mapping" {
    result=$(build_docker_ports)
    [[ "$result" =~ -p\ 127\.0\.0\.1::4096 ]]
}

@test "build_docker_ports includes additional ports" {
    ADDITIONAL_PORTS=(3000 8080)
    result=$(build_docker_ports)
    [[ "$result" =~ -p\ 127\.0\.0\.1::3000 ]]
    [[ "$result" =~ -p\ 127\.0\.0\.1::8080 ]]
}

@test "build_docker_ports uses 0.0.0.0 for public" {
    result=$(IS_PUBLIC=true ADDITIONAL_PORTS=() build_docker_ports)
    [[ "$result" =~ -p\ 0\.0\.0\.0::4096 ]]
}

@test "parse_args handles -p flag" {
    ADDITIONAL_PORTS=()
    parse_args -p 3000
    [ "${ADDITIONAL_PORTS[0]}" = "3000" ]
}

@test "parse_args handles multiple -p flags" {
    ADDITIONAL_PORTS=()
    parse_args -p 3000 -p 8080
    [ "${ADDITIONAL_PORTS[0]}" = "3000" ]
    [ "${ADDITIONAL_PORTS[1]}" = "8080" ]
}

@test "parse_args handles --public flag" {
    IS_PUBLIC=false
    parse_args --public
    [ "$IS_PUBLIC" = "true" ]
}

@test "parse_args errors on missing port value" {
    run parse_args -p
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: -p/--port requires a port number" ]]
}

@test "parse_args errors on unknown option" {
    run parse_args --unknown
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "parse_global_flags handles --worktree" {
    USE_WORKTREE=false
    REMAINING_ARGS=()
    parse_global_flags --worktree start
    [ "$USE_WORKTREE" = "true" ]
}

@test "parse_global_flags preserves remaining args" {
    USE_WORKTREE=false
    REMAINING_ARGS=()
    parse_global_flags start --public
    [ "${#REMAINING_ARGS[@]}" -gt 0 ]
}

@test "check_docker fails when docker not installed" {
    PATH="/nonexistent" run check_docker
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Docker" ]]
}

@test "check_server returns 1 when port is closed" {
    run check_server 127.0.0.1 59999
    [ "$status" -eq 1 ]
}

@test "cmd_help displays usage" {
    run cmd_help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Commands:" ]]
}
