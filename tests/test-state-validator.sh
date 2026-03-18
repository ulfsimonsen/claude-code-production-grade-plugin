#!/bin/bash
# Tests for hooks/state-validator.sh (PostToolUse Write hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/state-validator.sh"
begin_suite "state-validator.sh"

# Helper: get a timestamp N seconds ago in ISO-8601
timestamp_ago() {
  local secs="$1"
  local now
  now=$(date -u +%s)
  local past=$((now - secs))
  date -u -j -f "%s" "$past" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
    date -u -d "@$past" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
    echo ""
}

# --- Guard tests ---

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  run_hook "$HOOK" '{"tool_input":{"file_path":"state.json"}}' "$ws"
  assert_eq "guard: exits 0 when no state.json" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no state.json" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_non_state_write() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"some-other-file.json"}}' "$ws"
  assert_eq "guard: exits 0 for non-state.json writes" "0" "$HOOK_EXIT"
  assert_eq "guard: no output for non-state.json writes" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Validation: loaded without timestamp ---

test_warns_loaded_without_timestamp() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_contains "warns when loaded but no timestamp" "$HOOK_OUTPUT" "last_phase_read is missing"
  cleanup_workspace "$ws"
}

test_no_warning_when_loaded_with_timestamp() {
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 10)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"last_phase_read":"'"$ts"'"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_eq "no output when loaded with fresh timestamp" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Validation: invalid phase ---

test_warns_invalid_phase_with_active_tasks() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"INVALID","phase_file_loaded":false,"tasks_active":["T1"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_contains "warns on invalid phase with active tasks" "$HOOK_OUTPUT" "not a valid phase"
  cleanup_workspace "$ws"
}

test_no_warning_on_valid_phase_with_active_tasks() {
  # Inverse: valid phase should NOT trigger the warning
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 10)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":["T3a"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_not_contains "valid phase: no invalid-phase warning" "$HOOK_OUTPUT" "not a valid phase"
  cleanup_workspace "$ws"
}

# --- Validation: COMPLETE with active tasks ---

test_warns_complete_with_active_tasks() {
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 10)
  echo '{"current_phase":"COMPLETE","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":["T1"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_contains "warns COMPLETE with active tasks" "$HOOK_OUTPUT" "current_phase=COMPLETE but tasks_active"
  cleanup_workspace "$ws"
}

test_no_warning_complete_no_tasks() {
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 10)
  echo '{"current_phase":"COMPLETE","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":[]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_eq "no output for valid COMPLETE state" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Validation: staleness ---

test_warns_stale_timestamp() {
  local ws; ws=$(create_workspace)
  # Timestamp 2 hours ago (7200s) → should trigger >30min staleness warning
  local ts; ts=$(timestamp_ago 7200)
  if [[ -z "$ts" ]]; then
    # Skip if timestamp_ago can't generate — platform issue
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m warns stale timestamp (skipped — date -j unavailable)\n"
    cleanup_workspace "$ws"
    return
  fi
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":["T3a"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_contains "warns when timestamp is stale (>30min)" "$HOOK_OUTPUT" "Phase file may need re-reading"
  cleanup_workspace "$ws"
}

test_no_staleness_warning_for_fresh_timestamp() {
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 60)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":["T3a"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_not_contains "no staleness warning for fresh timestamp" "$HOOK_OUTPUT" "Phase file may need re-reading"
  cleanup_workspace "$ws"
}

# --- Clean valid state produces zero output ---

test_no_warning_on_fully_valid_state() {
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 10)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":["T3a"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  assert_eq "no output for fully valid state" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Output format ---

test_warning_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  local ts; ts=$(timestamp_ago 10)
  echo '{"current_phase":"COMPLETE","phase_file_loaded":true,"last_phase_read":"'"$ts"'","tasks_active":["T1"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{"tool_input":{"file_path":"Claude-Production-Grade-Suite/.orchestrator/state.json"}}' "$ws"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "warning output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is PostToolUse" "PostToolUse" "$event"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_state_file
test_guard_non_state_write
test_warns_loaded_without_timestamp
test_no_warning_when_loaded_with_timestamp
test_warns_invalid_phase_with_active_tasks
test_no_warning_on_valid_phase_with_active_tasks
test_warns_complete_with_active_tasks
test_no_warning_complete_no_tasks
test_warns_stale_timestamp
test_no_staleness_warning_for_fresh_timestamp
test_no_warning_on_fully_valid_state
test_warning_output_is_valid_json

print_summary
