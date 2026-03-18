#!/bin/bash
# Tests for hooks/phase-loader.sh (PreToolUse Agent hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/phase-loader.sh"
begin_suite "phase-loader.sh"

# --- Guard tests ---

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  # No state.json exists — hook should be inert
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

# --- Deny behavior tests (Layer 1) ---

test_deny_first_attempt() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "first attempt: denies agent dispatch" "deny" "$decision"
  assert_contains "first attempt: includes BLOCKED message" "$HOOK_OUTPUT" "Agent dispatch BLOCKED"
  assert_contains "first attempt: shows attempt count" "$HOOK_OUTPUT" "attempt 1/2"
  assert_contains "first attempt: tells to read phase file" "$HOOK_OUTPUT" "build.md"
  cleanup_workspace "$ws"
}

test_deny_second_attempt() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "1" > "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build"
  run_hook "$HOOK" '{}' "$ws"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "second attempt: denies agent dispatch" "deny" "$decision"
  assert_contains "second attempt: shows attempt count" "$HOOK_OUTPUT" "attempt 2/2"
  cleanup_workspace "$ws"
}

test_fallback_after_two_denies() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "2" > "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build"
  run_hook "$HOOK" '{}' "$ws"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "fallback: allows agent dispatch after 2 denies" "allow" "$decision"
  assert_contains "fallback: includes FALLBACK message" "$HOOK_OUTPUT" "PHASE ENFORCEMENT FALLBACK"
  assert_contains "fallback: mentions the phase file wasn't read" "$HOOK_OUTPUT" "NOT read"
  cleanup_workspace "$ws"
}

test_fallback_injects_critical_directives_when_available() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SUSTAIN","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "2" > "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-sustain"
  # Run with CLAUDE_PLUGIN_ROOT set so it can find the critical file
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "fallback: injects critical directives" "$HOOK_OUTPUT" "TeamDelete"
  assert_contains "fallback: includes CRITICAL DIRECTIVES label" "$HOOK_OUTPUT" "CRITICAL DIRECTIVES"
  cleanup_workspace "$ws"
}

test_fallback_without_critical_file_still_works() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "2" > "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build"
  # No CLAUDE_PLUGIN_ROOT → critical file won't be found
  run_hook "$HOOK" '{}' "$ws"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "fallback without critical file: still allows" "allow" "$decision"
  assert_contains "fallback without critical file: still includes FALLBACK msg" "$HOOK_OUTPUT" "PHASE ENFORCEMENT FALLBACK"
  # Should NOT contain CRITICAL DIRECTIVES since no file was found
  assert_not_contains "fallback without critical file: no CRITICAL DIRECTIVES" "$HOOK_OUTPUT" "CRITICAL DIRECTIVES"
  cleanup_workspace "$ws"
}

test_deny_counter_increments() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"HARDEN","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  local count
  count=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-harden")
  assert_eq "deny counter increments to 1" "1" "$count"
  cleanup_workspace "$ws"
}

test_deny_counter_increments_sequentially() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # First call
  run_hook "$HOOK" '{}' "$ws"
  local count1
  count1=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build")
  assert_eq "counter is 1 after first deny" "1" "$count1"
  # Second call
  run_hook "$HOOK" '{}' "$ws"
  local count2
  count2=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build")
  assert_eq "counter is 2 after second deny" "2" "$count2"
  cleanup_workspace "$ws"
}

test_deny_counter_resets_when_loaded() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "2" > "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build"
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "exits 0 when loaded" "0" "$HOOK_EXIT"
  local exists="false"
  [[ -f "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build" ]] && exists="true"
  assert_eq "deny counter reset when phase loaded" "false" "$exists"
  cleanup_workspace "$ws"
}

# --- Verify deny actually prevents allow ---

test_deny_is_not_allow() {
  # This test exists to catch a regression where deny might accidentally
  # become allow. If the hook ever outputs "allow" when phase_file_loaded=false
  # and deny count < 2, this test will fail.
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SHIP","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_not_contains "deny must not output allow" "$HOOK_OUTPUT" '"permissionDecision": "allow"'
  # Also verify it's not silently passing through (exit 0 with no output)
  local has_output="false"
  [[ -n "$HOOK_OUTPUT" ]] && has_output="true"
  assert_eq "deny produces output (not silent pass-through)" "true" "$has_output"
  cleanup_workspace "$ws"
}

# --- Silent pass-through ---

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

test_deny_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "deny output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is PreToolUse" "PreToolUse" "$event"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "permissionDecision is deny" "deny" "$decision"
  cleanup_workspace "$ws"
}

test_fallback_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":false}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "2" > "$ws/Claude-Production-Grade-Suite/.orchestrator/.deny-count-build"
  run_hook "$HOOK" '{}' "$ws"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "fallback output is valid JSON" "0" "$?"
  local decision
  decision=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.permissionDecision')
  assert_eq "fallback permissionDecision is allow" "allow" "$decision"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_state_file
test_guard_no_phase
test_deny_first_attempt
test_deny_second_attempt
test_fallback_after_two_denies
test_fallback_injects_critical_directives_when_available
test_fallback_without_critical_file_still_works
test_deny_counter_increments
test_deny_counter_increments_sequentially
test_deny_counter_resets_when_loaded
test_deny_is_not_allow
test_silent_when_phase_already_loaded
test_maps_define_phase
test_maps_harden_phase
test_maps_ship_phase
test_maps_sustain_phase
test_unknown_phase_exits_silently
test_deny_output_is_valid_json
test_fallback_output_is_valid_json

print_summary
