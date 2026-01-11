#!/usr/bin/env bats

# Load test helper
load 'test_helper'

setup() {
    source_functions
    TEMP_DIR=$(mktemp -d)
    MOCK_TRANSCRIPT="$TEMP_DIR/transcript.jsonl"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

# =============================================================================
# generate_preview() tests
# =============================================================================

@test "generate_preview: returns short text unchanged" {
    result=$(generate_preview "Hello world")
    [[ "$result" == "Hello world" ]]
}

@test "generate_preview: truncates text longer than PREVIEW_LENGTH" {
    long_text="This is a very long text that exceeds the preview length limit and should be truncated with ellipsis at the end"
    result=$(generate_preview "$long_text")
    [[ ${#result} -le $((PREVIEW_LENGTH + 3)) ]]  # +3 for "..."
    [[ "$result" == *"..." ]]
}

@test "generate_preview: returns <empty> for whitespace-only input" {
    result=$(generate_preview "   ")
    [[ "$result" == "<empty>" ]]
}

@test "generate_preview: returns <empty> for empty input" {
    result=$(generate_preview "")
    [[ "$result" == "<empty>" ]]
}

@test "generate_preview: skips leading blank lines" {
    result=$(generate_preview $'\n\n\nActual content here')
    [[ "$result" == "Actual content here" ]]
}

@test "generate_preview: handles multiline text (takes first non-empty line)" {
    result=$(generate_preview $'First line\nSecond line\nThird line')
    [[ "$result" == "First line" ]]
}

# =============================================================================
# Command matching tests
# =============================================================================

@test "matches_command: accepts basic -copy" {
    matches_command "-copy"
}

@test "matches_command: accepts -copy with number" {
    matches_command "-copy 1"
    matches_command "-copy 42"
    matches_command "-copy 999"
}

@test "matches_command: accepts -copy -ls" {
    matches_command "-copy -ls"
}

@test "matches_command: accepts -copy -ls with count" {
    matches_command "-copy -ls 5"
    matches_command "-copy -ls 20"
}

@test "matches_command: accepts -copy -f with search term" {
    matches_command "-copy -f error"
    matches_command "-copy -f git commit"
}

@test "matches_command: accepts -copy -fr with regex" {
    matches_command "-copy -fr error.*fix"
    matches_command "-copy -fr TODO|FIXME"
}

@test "matches_command: accepts -copy -debug" {
    matches_command "-copy -debug"
    matches_command "-copy -debug 3"
}

@test "matches_command: rejects invalid commands" {
    ! matches_command "copy"
    ! matches_command "-copy invalid"
    ! matches_command "-copy -x"
    ! matches_command "-copy -ls abc"
    ! matches_command "hello -copy"
}

@test "matches_command: rejects partial matches" {
    ! matches_command "-copyextra"
    ! matches_command "-copy-more"
}

# =============================================================================
# Specific mode matching tests
# =============================================================================

@test "matches_list_mode: matches -copy -ls variants" {
    matches_list_mode "-copy -ls"
    matches_list_mode "-copy -ls 5"
    matches_list_mode "-copy -ls 100"
}

@test "matches_list_mode: rejects non-list commands" {
    ! matches_list_mode "-copy"
    ! matches_list_mode "-copy 5"
    ! matches_list_mode "-copy -f test"
}

@test "matches_find_mode: matches -copy -f variants" {
    matches_find_mode "-copy -f error"
    matches_find_mode "-copy -f multiple words"
}

@test "matches_find_mode: rejects regex mode" {
    ! matches_find_mode "-copy -fr pattern"
}

@test "matches_find_regex_mode: matches -copy -fr variants" {
    matches_find_regex_mode "-copy -fr error.*fix"
    matches_find_regex_mode "-copy -fr [a-z]+"
}

@test "matches_debug_mode: matches -copy -debug variants" {
    matches_debug_mode "-copy -debug"
    matches_debug_mode "-copy -debug 1"
    matches_debug_mode "-copy -debug 42"
}

@test "matches_numbered: matches -copy with number" {
    matches_numbered "-copy 1"
    matches_numbered "-copy 99"
}

@test "matches_numbered: rejects non-numbered" {
    ! matches_numbered "-copy"
    ! matches_numbered "-copy -ls"
}

# =============================================================================
# format_time_ago() tests
# =============================================================================

@test "format_time_ago: returns empty for null timestamp" {
    result=$(format_time_ago "null")
    [[ -z "$result" ]]
}

@test "format_time_ago: returns empty for empty timestamp" {
    result=$(format_time_ago "")
    [[ -z "$result" ]]
}

@test "format_time_ago: formats recent time as seconds" {
    # Create a timestamp 30 seconds ago
    now=$(date +%s)
    past=$((now - 30))
    timestamp=$(date -j -f "%s" "$past" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null)
    if [[ -n "$timestamp" ]]; then
        result=$(format_time_ago "$timestamp")
        [[ "$result" =~ \[[[:space:]]*[0-9]+s\ ago\] ]]
    else
        skip "date -j not available on this platform"
    fi
}

@test "format_time_ago: formats minutes correctly" {
    now=$(date +%s)
    past=$((now - 300))  # 5 minutes ago
    timestamp=$(date -j -f "%s" "$past" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null)
    if [[ -n "$timestamp" ]]; then
        result=$(format_time_ago "$timestamp")
        [[ "$result" =~ \[[[:space:]]*[0-9]+m\ ago\] ]]
    else
        skip "date -j not available on this platform"
    fi
}

@test "format_time_ago: formats hours correctly" {
    now=$(date +%s)
    past=$((now - 7200))  # 2 hours ago
    timestamp=$(date -j -f "%s" "$past" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null)
    if [[ -n "$timestamp" ]]; then
        result=$(format_time_ago "$timestamp")
        [[ "$result" =~ \[[[:space:]]*[0-9]+h\ ago\] ]]
    else
        skip "date -j not available on this platform"
    fi
}

# =============================================================================
# Integration tests (with mock transcript)
# =============================================================================

@test "script: exits silently for non-matching prompts" {
    create_mock_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"hello world","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1)
    [[ -z "$result" ]]
}

@test "script: requires jq for -copy command" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq not installed - this test verifies jq error handling"
    fi
    # This test verifies that the script works when jq IS available
    create_mock_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"-copy","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1)
    [[ "$result" == *"copied"* ]] || [[ "$result" == *"block"* ]]
}

@test "script: -copy -ls lists responses" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq required for this test"
    fi
    create_mock_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"-copy -ls","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1) || true
    [[ "$result" == *"Responses"* ]]
}

@test "script: -copy -f searches responses" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq required for this test"
    fi
    create_mock_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"-copy -f error","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1) || true
    [[ "$result" == *"Searching"* ]]
}

@test "script: -copy -fr searches with regex" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq required for this test"
    fi
    create_mock_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"-copy -fr error.*test","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1) || true
    [[ "$result" == *"Regex search"* ]]
}

@test "script: handles multi-part responses correctly" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq required for this test"
    fi
    create_multipart_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"-copy -ls","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1) || true
    # Should show 2 responses (grouped by requestId)
    [[ "$result" == *"1-2"* ]] || [[ "$result" == *"showing 2"* ]]
}

@test "script: invalid response number shows error" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq required for this test"
    fi
    create_mock_transcript "$MOCK_TRANSCRIPT"
    input='{"prompt":"-copy 999","transcript_path":"'"$MOCK_TRANSCRIPT"'"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1) || true
    [[ "$result" == *"Invalid"* ]]
}

@test "script: handles missing transcript gracefully" {
    input='{"prompt":"-copy","transcript_path":"/nonexistent/path"}'
    result=$(echo "$input" | "$BATS_TEST_DIRNAME/../copy-claude-response" 2>&1) || true
    [[ "$result" == *"No valid transcript"* ]] || [[ -z "$result" ]]
}

# =============================================================================
# copy_to_clipboard() tests
# =============================================================================

@test "copy_to_clipboard: copies text successfully" {
    if ! command -v pbcopy >/dev/null 2>&1; then
        skip "pbcopy not available (not on macOS)"
    fi
    copy_to_clipboard "test content"
    result=$(pbpaste)
    [[ "$result" == "test content" ]]
}

@test "copy_to_clipboard: handles special characters" {
    if ! command -v pbcopy >/dev/null 2>&1; then
        skip "pbcopy not available (not on macOS)"
    fi
    copy_to_clipboard 'Line 1\nLine 2\t"quoted"'
    result=$(pbpaste)
    [[ "$result" == 'Line 1\nLine 2\t"quoted"' ]]
}

@test "copy_to_clipboard: handles unicode" {
    if ! command -v pbcopy >/dev/null 2>&1; then
        skip "pbcopy not available (not on macOS)"
    fi
    copy_to_clipboard "Hello 世界 🌍"
    result=$(pbpaste)
    [[ "$result" == "Hello 世界 🌍" ]]
}
