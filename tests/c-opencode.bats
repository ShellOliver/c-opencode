#!/usr/bin/env bats

setup() {
    export REMAINING_ARGS=()
    export SERVER_HOST="0.0.0.0"
    export SERVER_PORT=4096
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
    [[ "$output" =~ "Pass-through:" ]]
    [[ "$output" =~ "Container Management" ]]
}

@test "main function dispatches help" {
    run main help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "main function shows help with -h flag" {
    run main -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "main function shows help with --help flag" {
    run main --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}
