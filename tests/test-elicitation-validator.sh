#!/bin/bash
# Tests for hooks/elicitation-validator.sh (PreToolUse Elicitation hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/elicitation-validator.sh"
begin_suite "elicitation-validator.sh"

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

# --- Validation: valid form with free-form field ---

test_valid_form_with_freeform() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_input":{"title":"Choose engagement","fields":[{"type":"select","name":"mode","options":["express","thorough"]},{"type":"text","name":"notes"}]}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0 for valid form" "0" "$HOOK_EXIT"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "always allows elicitation" "allow" "$decision"
  assert_contains "context says form validated" "$HOOK_OUTPUT" "form validated"
  assert_contains "context mentions title" "$HOOK_OUTPUT" "Choose engagement"
  assert_contains "context says free-form present" "$HOOK_OUTPUT" "free-form present"
  # Should NOT have logged warnings
  local has_error_log="false"
  [[ -f "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md" ]] && has_error_log="true"
  assert_eq "no error log for valid form" "false" "$has_error_log"
  cleanup_workspace "$ws"
}

# --- Validation: form missing free-form field ---

test_warns_no_freeform_field() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_input":{"title":"Pick option","fields":[{"type":"select","name":"choice","options":["a","b"]}]}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0 (never blocks)" "0" "$HOOK_EXIT"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "still allows even with warning" "allow" "$decision"
  assert_contains "context mentions free-form warning" "$HOOK_OUTPUT" "no_free_form_field_recommended"
  # Should have written to error log
  assert_file_exists "writes error log for warning" "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md"
  local log
  log=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md")
  assert_contains "error log mentions warning" "$log" "no_free_form_field_recommended"
  assert_contains "error log mentions title" "$log" "Pick option"
  cleanup_workspace "$ws"
}

# --- Validation: form with zero fields ---

test_warns_no_fields() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SHIP"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_input":{"title":"Empty form","fields":[]}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "warns about no fields" "$HOOK_OUTPUT" "no_fields_defined"
  cleanup_workspace "$ws"
}

# --- Validation: textarea counts as free-form ---

test_textarea_counts_as_freeform() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_input":{"title":"Feedback","fields":[{"type":"textarea","name":"comments"}]}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_not_contains "no free-form warning for textarea" "$HOOK_OUTPUT" "no_free_form_field_recommended"
  assert_contains "context says free-form present" "$HOOK_OUTPUT" "free-form present"
  cleanup_workspace "$ws"
}

# --- Output format ---

test_output_format() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"tool_input":{"title":"Test","fields":[{"type":"text","name":"input"}]}}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is PreToolUse" "PreToolUse" "$event"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_plugin_root
test_guard_no_state_file
test_valid_form_with_freeform
test_warns_no_freeform_field
test_warns_no_fields
test_textarea_counts_as_freeform
test_output_format

print_summary
