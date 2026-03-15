#!/bin/bash
# Tests for hooks/pre-compact-snapshot.sh (PreCompact hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/pre-compact-snapshot.sh"
begin_suite "pre-compact-snapshot.sh"

# --- Guard tests ---

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  run_hook "$HOOK" '' "$ws"
  assert_eq "guard: exits 0 when no state.json" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Snapshot creation ---

test_creates_snapshot_file() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","current_wave":"A"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '' "$ws"
  assert_eq "exits 0" "0" "$HOOK_EXIT"
  assert_file_exists "creates pre-compact-snapshot.json" "$ws/Claude-Production-Grade-Suite/.orchestrator/pre-compact-snapshot.json"
  cleanup_workspace "$ws"
}

test_snapshot_preserves_state() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"HARDEN","current_wave":"B","tasks_completed":["T1","T2","T3a"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '' "$ws"
  local snapshot="$ws/Claude-Production-Grade-Suite/.orchestrator/pre-compact-snapshot.json"
  local phase
  phase=$(jq -r '.current_phase' "$snapshot")
  assert_eq "snapshot preserves current_phase" "HARDEN" "$phase"
  local wave
  wave=$(jq -r '.current_wave' "$snapshot")
  assert_eq "snapshot preserves current_wave" "B" "$wave"
  local tasks
  tasks=$(jq -r '.tasks_completed | length' "$snapshot")
  assert_eq "snapshot preserves tasks_completed count" "3" "$tasks"
  cleanup_workspace "$ws"
}

test_snapshot_adds_receipt_count() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # Create some receipt files
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-pm.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T2-arch.json"
  run_hook "$HOOK" '' "$ws"
  local snapshot="$ws/Claude-Production-Grade-Suite/.orchestrator/pre-compact-snapshot.json"
  local count
  count=$(jq -r '.receipt_count_at_compact' "$snapshot")
  assert_eq "snapshot includes receipt count" "2" "$count"
  cleanup_workspace "$ws"
}

test_snapshot_adds_receipt_list() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-pm.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T2-arch.json"
  run_hook "$HOOK" '' "$ws"
  local snapshot="$ws/Claude-Production-Grade-Suite/.orchestrator/pre-compact-snapshot.json"
  local list
  list=$(jq -r '.receipts_at_compact' "$snapshot")
  assert_contains "receipt list includes T1-pm" "$list" "T1-pm"
  assert_contains "receipt list includes T2-arch" "$list" "T2-arch"
  cleanup_workspace "$ws"
}

test_snapshot_adds_compacted_at_timestamp() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  run_hook "$HOOK" '' "$ws"
  local snapshot="$ws/Claude-Production-Grade-Suite/.orchestrator/pre-compact-snapshot.json"
  local ts
  ts=$(jq -r '.compacted_at' "$snapshot")
  # Should be an ISO-8601 timestamp like 2026-03-15T...
  assert_contains "compacted_at has date prefix" "$ts" "20"
  assert_contains "compacted_at has T separator" "$ts" "T"
  cleanup_workspace "$ws"
}

test_snapshot_zero_receipts() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # No receipt files
  run_hook "$HOOK" '' "$ws"
  local snapshot="$ws/Claude-Production-Grade-Suite/.orchestrator/pre-compact-snapshot.json"
  local count
  count=$(jq -r '.receipt_count_at_compact' "$snapshot")
  assert_eq "snapshot shows 0 receipts when none exist" "0" "$count"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_state_file
test_creates_snapshot_file
test_snapshot_preserves_state
test_snapshot_adds_receipt_count
test_snapshot_adds_receipt_list
test_snapshot_adds_compacted_at_timestamp
test_snapshot_zero_receipts

print_summary
