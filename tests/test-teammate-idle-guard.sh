#!/bin/bash
# Tests for hooks/teammate-idle-guard.sh (TeammateIdle hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/teammate-idle-guard.sh"
begin_suite "teammate-idle-guard.sh"

# --- Guard tests ---

test_guard_no_suite_dir() {
  local ws; ws=$(create_workspace)
  rm -rf "$ws/Claude-Production-Grade-Suite"
  run_hook "$HOOK" '{"team_name":"production-grade"}' "$ws"
  assert_eq "guard: exits 0 when no suite dir" "0" "$HOOK_EXIT"
  # No suite dir → hook exits silently (no output, no stop)
  assert_eq "guard: no output when no suite dir" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_non_production_grade_team() {
  local ws; ws=$(create_workspace)
  run_hook "$HOOK" '{"team_name":"other-team"}' "$ws"
  assert_eq "guard: exits 0 for non-production-grade team" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Stop behavior for completed pipelines ---

test_stops_when_pipeline_complete() {
  local ws; ws=$(create_workspace)
  echo "complete" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '{"team_name":"production-grade"}' "$ws"
  assert_eq "exits 0 when pipeline complete" "0" "$HOOK_EXIT"
  local cont
  cont=$(echo "$HOOK_OUTPUT" | grep -o '"continue"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | grep -o '[a-z]*$')
  assert_eq "stops teammate when pipeline complete" "false" "$cont"
  assert_contains "stop reason mentions finished" "$HOOK_OUTPUT" "finished"
  cleanup_workspace "$ws"
}

test_stops_when_pipeline_rejected() {
  local ws; ws=$(create_workspace)
  echo "rejected" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '{"team_name":"production-grade"}' "$ws"
  local cont
  cont=$(echo "$HOOK_OUTPUT" | grep -o '"continue"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | grep -o '[a-z]*$')
  assert_eq "stops teammate when pipeline rejected" "false" "$cont"
  cleanup_workspace "$ws"
}

test_stops_when_T13_receipt_exists() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T13-assembly.json"
  run_hook "$HOOK" '{"team_name":"production-grade"}' "$ws"
  local cont
  cont=$(echo "$HOOK_OUTPUT" | grep -o '"continue"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | grep -o '[a-z]*$')
  assert_eq "stops teammate when T13 receipt exists" "false" "$cont"
  assert_contains "stop reason mentions T13" "$HOOK_OUTPUT" "T13"
  cleanup_workspace "$ws"
}

# --- Continue behavior for active pipelines ---

test_continues_when_pipeline_active() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json"
  # No pipeline-status marker, no T13 receipt → active
  run_hook "$HOOK" '{"team_name":"production-grade"}' "$ws"
  local cont
  cont=$(echo "$HOOK_OUTPUT" | grep -o '"continue"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | grep -o '[a-z]*$')
  assert_eq "continues when pipeline active" "true" "$cont"
  cleanup_workspace "$ws"
}

test_continues_when_partial_status() {
  local ws; ws=$(create_workspace)
  echo "partial" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '{"team_name":"production-grade"}' "$ws"
  local cont
  cont=$(echo "$HOOK_OUTPUT" | grep -o '"continue"[[:space:]]*:[[:space:]]*[a-z]*' | head -1 | grep -o '[a-z]*$')
  assert_eq "continues when status is partial" "true" "$cont"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_suite_dir
test_guard_non_production_grade_team
test_stops_when_pipeline_complete
test_stops_when_pipeline_rejected
test_stops_when_T13_receipt_exists
test_continues_when_pipeline_active
test_continues_when_partial_status

print_summary
