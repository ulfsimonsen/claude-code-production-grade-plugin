#!/bin/bash
# Tests for hooks/phase-loader.sh (PreToolUse Agent hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/phase-loader.sh"
begin_suite "phase-loader.sh"

# --- Guard tests ---

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  # No state.json exists
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "guard: exits 0 when no state.json" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no state.json" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_no_phase() {
  local ws; ws=$(create_workspace)
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "guard: exits 0 when no current_phase in state" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Phase reminder tests ---

test_reminder_when_phase_not_loaded() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "outputs phase loading reminder" "$HOOK_OUTPUT" "PHASE LOADING REQUIRED"
  assert_contains "includes correct filename" "$HOOK_OUTPUT" "build.md"
  cleanup_workspace "$ws"
}

test_silent_when_phase_already_loaded() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "exits 0 when phase already loaded" "0" "$HOOK_EXIT"
  assert_eq "no output when phase already loaded" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Phase name mapping ---

test_maps_define_phase() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "maps DEFINE to define.md" "$HOOK_OUTPUT" "define.md"
  cleanup_workspace "$ws"
}

test_maps_harden_phase() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"HARDEN","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "maps HARDEN to harden.md" "$HOOK_OUTPUT" "harden.md"
  cleanup_workspace "$ws"
}

test_maps_ship_phase() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SHIP","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "maps SHIP to ship.md" "$HOOK_OUTPUT" "ship.md"
  cleanup_workspace "$ws"
}

test_maps_sustain_phase() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SUSTAIN","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "maps SUSTAIN to sustain.md" "$HOOK_OUTPUT" "sustain.md"
  cleanup_workspace "$ws"
}

test_unknown_phase_exits_silently() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"UNKNOWN","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "exits 0 for unknown phase" "0" "$HOOK_EXIT"
  assert_eq "no output for unknown phase" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Output format ---

test_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is PreToolUse" "PreToolUse" "$event"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "permissionDecision is allow" "allow" "$decision"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_state_file
test_guard_no_phase
test_reminder_when_phase_not_loaded
test_silent_when_phase_already_loaded
test_maps_define_phase
test_maps_harden_phase
test_maps_ship_phase
test_maps_sustain_phase
test_unknown_phase_exits_silently
test_output_is_valid_json

print_summary
