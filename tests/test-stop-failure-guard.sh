#!/bin/bash
# Tests for hooks/stop-failure-guard.sh (StopFailure hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/stop-failure-guard.sh"
begin_suite "stop-failure-guard.sh"

# --- Guard tests ---

test_guard_no_plugin_root() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && unset CLAUDE_PLUGIN_ROOT && echo '{}' | bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 without CLAUDE_PLUGIN_ROOT" "0" "$HOOK_EXIT"
  assert_eq "guard: no output without CLAUDE_PLUGIN_ROOT" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  rm -f "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 without state.json" "0" "$HOOK_EXIT"
  assert_eq "guard: no output without state.json" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Rate limit handling ---

test_rate_limit_guidance() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","current_wave":"A"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"error_type":"rate_limit","error_message":"Too many requests"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0" "0" "$HOOK_EXIT"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  assert_contains "guidance says pause" "$HOOK_OUTPUT" "pause 60 seconds"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is StopFailure" "StopFailure" "$event"
  # Check error log written
  assert_file_exists "writes error log" "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md"
  local log
  log=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md")
  assert_contains "log has rate_limit" "$log" "rate_limit"
  assert_contains "log has phase" "$log" "BUILD"
  assert_contains "log has wave" "$log" "A"
  cleanup_workspace "$ws"
}

# --- Auth error handling ---

test_auth_error_guidance() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SHIP","current_wave":"C"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"error_type":"auth","error_message":"Invalid API key"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "guidance mentions authentication" "$HOOK_OUTPUT" "Authentication failure"
  assert_contains "guidance mentions API key" "$HOOK_OUTPUT" "API key"
  cleanup_workspace "$ws"
}

# --- Unknown error handling ---

test_unknown_error_guidance() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"HARDEN","current_wave":"B"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"error_type":"server_error","error_message":"Internal error"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "guidance mentions error type" "$HOOK_OUTPUT" "server_error"
  assert_contains "guidance says retry" "$HOOK_OUTPUT" "Retry"
  cleanup_workspace "$ws"
}

# --- Error log content ---

test_error_log_content() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SUSTAIN","current_wave":"D"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"error_type":"RateLimitError","message":"Rate limited"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local log
  log=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md")
  assert_contains "log header is StopFailure" "$log" "StopFailure"
  assert_contains "log has SUSTAIN phase" "$log" "SUSTAIN"
  assert_contains "log has wave D" "$log" "D"
  assert_contains "log has RateLimitError" "$log" "RateLimitError"
  # RateLimitError should match rate_limit guidance
  assert_contains "RateLimitError triggers pause guidance" "$HOOK_OUTPUT" "pause 60 seconds"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_plugin_root
test_guard_no_state_file
test_rate_limit_guidance
test_auth_error_guidance
test_unknown_error_guidance
test_error_log_content

print_summary
