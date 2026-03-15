#!/bin/bash
# Tests for hooks/subagent-phase-injector.sh (SubagentStart hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/subagent-phase-injector.sh"
begin_suite "subagent-phase-injector.sh"

# --- Guard tests ---

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "guard: exits 0 when no state.json" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no state.json" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_no_phase() {
  local ws; ws=$(create_workspace)
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "guard: exits 0 when no current_phase" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Wave context injection ---

test_wave_a_context() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","current_wave":"A"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "includes phase BUILD" "$HOOK_OUTPUT" "Phase: BUILD"
  assert_contains "includes wave A" "$HOOK_OUTPUT" "Wave: A"
  assert_contains "wave A points to BRD" "$HOOK_OUTPUT" "BRD/brd.md"
  assert_contains "wave A points to architecture" "$HOOK_OUTPUT" "docs/architecture"
  cleanup_workspace "$ws"
}

test_wave_b_context() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"HARDEN","current_wave":"B"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "wave B points to test-plan" "$HOOK_OUTPUT" "test-plan.md"
  assert_contains "wave B points to threat-model" "$HOOK_OUTPUT" "threat-model"
  assert_contains "wave B points to checklist" "$HOOK_OUTPUT" "checklist.md"
  cleanup_workspace "$ws"
}

test_wave_c_context() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SHIP","current_wave":"C"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "wave C points to code-audit" "$HOOK_OUTPUT" "code-audit"
  assert_contains "wave C points to code-reviewer" "$HOOK_OUTPUT" "code-reviewer"
  assert_contains "wave C points to qa-engineer" "$HOOK_OUTPUT" "qa-engineer"
  cleanup_workspace "$ws"
}

test_wave_d_context() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SUSTAIN","current_wave":"D"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "wave D points to sre" "$HOOK_OUTPUT" "sre/"
  assert_contains "wave D points to runbooks" "$HOOK_OUTPUT" "runbooks"
  cleanup_workspace "$ws"
}

test_no_wave_still_outputs_phase() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE","current_wave":""}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "outputs phase even without wave" "$HOOK_OUTPUT" "Phase: DEFINE"
  cleanup_workspace "$ws"
}

# --- Settings integration ---

test_includes_engagement_from_settings() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","current_wave":"A"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local settings_dir="$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "Engagement: thorough" > "$settings_dir/settings.md"
  run_hook "$HOOK" '{}' "$ws"
  assert_contains "includes engagement mode" "$HOOK_OUTPUT" "Engagement: thorough"
  cleanup_workspace "$ws"
}

test_no_settings_file_still_works() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","current_wave":"A"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  assert_eq "works without settings.md" "0" "$HOOK_EXIT"
  assert_not_contains "no engagement when no settings" "$HOOK_OUTPUT" "Engagement:"
  cleanup_workspace "$ws"
}

# --- Output format ---

test_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","current_wave":"A"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '{}' "$ws"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is SubagentStart" "SubagentStart" "$event"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_state_file
test_guard_no_phase
test_wave_a_context
test_wave_b_context
test_wave_c_context
test_wave_d_context
test_no_wave_still_outputs_phase
test_includes_engagement_from_settings
test_no_settings_file_still_works
test_output_is_valid_json

print_summary
