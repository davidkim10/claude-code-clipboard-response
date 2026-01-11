#!/bin/bash

# Test helper for copy-claude-response tests

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
FIXTURES_DIR="$TEST_DIR/fixtures"

# Extract and source only the functions from the main script
# This avoids executing the main logic when sourcing for tests
source_functions() {
    # Extract function definitions from the script
    local script="$PROJECT_ROOT/copy-claude-response"

    # Source the constants
    COMMAND_NAME="-copy"
    PREVIEW_LENGTH=60
    DEFAULT_LIST_COUNT=10

    # Define the functions inline (extracted from main script)
    copy_to_clipboard() {
        local text="$1"
        if command -v pbcopy >/dev/null 2>&1; then
            printf '%s' "$text" | pbcopy
        elif command -v xclip >/dev/null 2>&1; then
            printf '%s' "$text" | xclip -selection clipboard
        elif command -v clip.exe >/dev/null 2>&1; then
            local temp_file=$(mktemp)
            printf '\xEF\xBB\xBF%s' "$text" > "$temp_file"
            powershell.exe -Command "Get-Content -Path '$(wslpath -w "$temp_file")' -Encoding UTF8 | Set-Clipboard"
            rm "$temp_file"
        else
            echo "No clipboard utility found (pbcopy, xclip, or clip.exe)" >&2
            return 1
        fi
    }

    generate_preview() {
        local text="$1"
        local preview=$(echo "$text" | grep -m1 -v '^[[:space:]]*$' | cut -c1-$PREVIEW_LENGTH)
        [[ -z "$preview" ]] && preview="<empty>"
        [[ ${#preview} -eq $PREVIEW_LENGTH ]] && preview="${preview}..."
        echo "$preview"
    }

    format_time_ago() {
        local timestamp="$1"
        [[ -z "$timestamp" || "$timestamp" == "null" ]] && return

        local now_epoch=$(date +%s)
        local msg_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp%%.*}" +%s 2>/dev/null || echo "$now_epoch")
        local diff=$((now_epoch - msg_epoch))

        if [[ $diff -lt 60 ]]; then
            printf "[%3ds ago]" "$diff"
        elif [[ $diff -lt 3600 ]]; then
            printf "[%3dm ago]" "$((diff/60))"
        else
            printf "[%3dh ago]" "$((diff/3600))"
        fi
    }

    # Command matching regex (for testing)
    matches_command() {
        local prompt="$1"
        [[ "$prompt" =~ ^${COMMAND_NAME}([[:space:]]+(-fr?[[:space:]]+.+|-ls([[:space:]]+[0-9]+)?|-debug([[:space:]]+[0-9]+)?|[0-9]+))?$ ]]
    }

    matches_list_mode() {
        local prompt="$1"
        [[ "$prompt" =~ ^${COMMAND_NAME}[[:space:]]+-ls([[:space:]]+([0-9]+))?$ ]]
    }

    matches_find_regex_mode() {
        local prompt="$1"
        [[ "$prompt" =~ ^${COMMAND_NAME}[[:space:]]+-fr[[:space:]]+(.+)$ ]]
    }

    matches_find_mode() {
        local prompt="$1"
        [[ "$prompt" =~ ^${COMMAND_NAME}[[:space:]]+-f[[:space:]]+(.+)$ ]]
    }

    matches_debug_mode() {
        local prompt="$1"
        [[ "$prompt" =~ ^${COMMAND_NAME}[[:space:]]+-debug([[:space:]]+([0-9]+))?$ ]]
    }

    matches_numbered() {
        local prompt="$1"
        [[ "$prompt" =~ ^${COMMAND_NAME}[[:space:]]+([0-9]+)$ ]]
    }
}

# Create a mock transcript file for testing
create_mock_transcript() {
    local file="$1"
    cat > "$file" << 'EOF'
{"requestId":"req1","message":{"role":"assistant","content":[{"text":"First response from Claude."}]},"timestamp":"2025-01-11T10:00:00.000Z"}
{"requestId":"req2","message":{"role":"assistant","content":[{"text":"Second response with error handling code."}]},"timestamp":"2025-01-11T10:05:00.000Z"}
{"requestId":"req3","message":{"role":"assistant","content":[{"text":"Third response about git commit commands."}]},"timestamp":"2025-01-11T10:10:00.000Z"}
EOF
}

# Create a multi-part response transcript
create_multipart_transcript() {
    local file="$1"
    cat > "$file" << 'EOF'
{"requestId":"req1","message":{"role":"assistant","content":[{"text":"Part 1 of response. "}]},"timestamp":"2025-01-11T10:00:00.000Z"}
{"requestId":"req1","message":{"role":"assistant","content":[{"text":"Part 2 of response."}]},"timestamp":"2025-01-11T10:00:01.000Z"}
{"requestId":"req2","message":{"role":"assistant","content":[{"text":"Complete second response."}]},"timestamp":"2025-01-11T10:05:00.000Z"}
EOF
}
