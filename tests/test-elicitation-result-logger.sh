#!/bin/bash
# Tests for hooks/elicitation-result-logger.sh (PostToolUse ElicitationResult hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/elicitation-result-logger.sh"
begin_suite "elicitation-result-logger.sh"

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

# --- Logging behavior ---

test_logs_elicitation_result() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_response":{"action":"submit","title":"Choose mode","values":{"mode":"express","notes":"fast"}}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0" "0" "$HOOK_EXIT"
  assert_file_exists "creates elicitation-log.md" "$ws/Claude-Production-Grade-Suite/.orchestrator/elicitation-log.md"
  local log
  log=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/elicitation-log.md")
  assert_contains "log includes phase" "$log" "DEFINE"
  assert_contains "log includes action" "$log" "submit"
  assert_contains "log includes form title" "$log" "Choose mode"
  assert_contains "log includes field count" "$log" "2"
  cleanup_workspace "$ws"
}

test_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_response":{"action":"cancel","title":"Test"}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is PostToolUse" "PostToolUse" "$event"
  assert_contains "context mentions action" "$HOOK_OUTPUT" "action=cancel"
  cleanup_workspace "$ws"
}

test_logs_append_not_overwrite() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # First call
  local input1='{"tool_response":{"action":"submit","title":"First form","values":{"a":"1"}}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  cd "$ws" && echo "$input1" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR" >/dev/null
  rm -f "$HOOK_STDERR"
  # Second call
  local input2='{"tool_response":{"action":"submit","title":"Second form","values":{"b":"2"}}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  cd "$ws" && echo "$input2" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR" >/dev/null
  rm -f "$HOOK_STDERR"
  local log
  log=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/elicitation-log.md")
  assert_contains "log has first form" "$log" "First form"
  assert_contains "log has second form" "$log" "Second form"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_plugin_root
test_guard_no_state_file
test_logs_elicitation_result
test_output_is_valid_json
test_logs_append_not_overwrite

print_summary
