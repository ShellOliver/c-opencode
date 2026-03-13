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

@test "sanitize_image_name handles special characters" {
    result=$(sanitize_image_name "My Project_v2")
    [ "$result" = "my-project-v2" ]

    result=$(sanitize_image_name "test@dev#123")
    [ "$result" = "test-dev-123" ]

    result=$(sanitize_image_name "UPPERCASE")
    [ "$result" = "uppercase" ]
}

@test "sanitize_image_name handles edge cases" {
    result=$(sanitize_image_name "  spaces  ")
    [ "$result" = "spaces" ]

    result=$(sanitize_image_name "---dashes---")
    [ "$result" = "dashes" ]

    result=$(sanitize_image_name "multiple---dashes")
    [ "$result" = "multiple-dashes" ]

    result=$(sanitize_image_name "")
    [ "$result" = "default" ]
}

@test "get_custom_image_name returns correct format" {
    cd /tmp || exit 1
    mkdir -p test_project
    cd test_project || exit 1

    result=$(get_custom_image_name)
    [[ "$result" =~ ^opencode-test-project:latest$ ]]

    cd /tmp || exit 1
    rm -rf test_project
}

@test "has_custom_build_script returns false when file missing" {
    cd /tmp || exit 1
    mkdir -p test_no_script
    cd test_no_script || exit 1

    run has_custom_build_script
    [ "$status" -eq 1 ]

    cd /tmp || exit 1
    rm -rf test_no_script
}

@test "has_custom_build_script returns true when file exists" {
    cd /tmp || exit 1
    mkdir -p test_with_script/.opencode
    cd test_with_script || exit 1

    touch .opencode/c-opencode-image.sh
    run has_custom_build_script
    [ "$status" -eq 0 ]

    cd /tmp || exit 1
    rm -rf test_with_script
}

@test "get_target_image returns default when no custom script" {
    cd /tmp || exit 1
    mkdir -p test_no_script
    cd test_no_script || exit 1

    result=$(get_target_image)
    [ "$result" = "opencode:latest" ]

    cd /tmp || exit 1
    rm -rf test_no_script
}

@test "get_yq_binary returns installed path first" {
    if [ -x "$HOME/.local/bin/yq" ]; then
        result=$(get_yq_binary)
        [ "$result" = "$HOME/.local/bin/yq" ]
    fi
}

@test "has_yq returns true when yq exists" {
    if [ -x "$HOME/.local/bin/yq" ]; then
        run has_yq
        [ "$status" -eq 0 ]
    fi
}

@test "get_port_flags generates correct Docker flags" {
    result=$(get_port_flags "3000:3000
8080:8080")
    [[ "$result" =~ "3000:3000" ]]
    [[ "$result" =~ "8080:8080" ]]
    [[ "$result" =~ "127.0.0.1::4096" ]]
}

@test "get_port_flags includes opencode port even when empty" {
    result=$(get_port_flags "")
    [[ "$result" =~ "127.0.0.1::4096" ]]
}
