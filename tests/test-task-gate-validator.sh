#!/bin/bash
# Tests for hooks/task-gate-validator.sh (TaskCompleted hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/task-gate-validator.sh"
begin_suite "task-gate-validator.sh"

# --- Guard tests ---

test_guard_non_production_grade_team() {
  local ws; ws=$(create_workspace)
  local input='{"task_subject":"T1: Product Manager","team_name":"other-team"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "guard: exits 0 for non-production-grade team" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

test_guard_no_task_id_in_subject() {
  local ws; ws=$(create_workspace)
  local input='{"task_subject":"General cleanup","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "guard: exits 0 when subject has no task ID" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Blocking tests (exit 2) ---

test_blocks_when_no_receipt() {
  local ws; ws=$(create_workspace)
  local input='{"task_subject":"T1: Product Manager","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "blocks completion when no receipt file exists" "2" "$HOOK_EXIT"
  assert_contains "error mentions missing receipt" "$HOOK_STDERR_CONTENT" "no receipt found"
  cleanup_workspace "$ws"
}

test_blocks_when_receipt_missing_fields() {
  local ws; ws=$(create_workspace)
  local receipt_dir="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo '{"task_id":"T1","skill":"product-manager"}' > "$receipt_dir/T1-product-manager.json"
  local input='{"task_subject":"T1: Product Manager","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "blocks completion when receipt missing fields" "2" "$HOOK_EXIT"
  assert_contains "error mentions missing fields" "$HOOK_STDERR_CONTENT" "missing required fields"
  cleanup_workspace "$ws"
}

test_blocks_when_effort_subfields_missing() {
  local ws; ws=$(create_workspace)
  local receipt_dir="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  cat > "$receipt_dir/T1-product-manager.json" <<'JSON'
{
  "task_id": "T1",
  "skill": "product-manager",
  "status": "completed",
  "completed_at": "2026-03-15T00:00:00Z",
  "artifacts": [],
  "metrics": {},
  "effort": {"files_read": 1}
}
JSON
  local input='{"task_subject":"T1: Product Manager","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "blocks when effort.files_written missing" "2" "$HOOK_EXIT"
  assert_contains "error mentions effort sub-field" "$HOOK_STDERR_CONTENT" "effort.files_written"
  cleanup_workspace "$ws"
}

test_blocks_when_artifact_missing_on_disk() {
  local ws; ws=$(create_workspace)
  local receipt_dir="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  cat > "$receipt_dir/T1-product-manager.json" <<JSON
{
  "task_id": "T1",
  "skill": "product-manager",
  "status": "completed",
  "completed_at": "2026-03-15T00:00:00Z",
  "artifacts": ["/nonexistent/brd.md"],
  "metrics": {},
  "effort": {"files_read": 1, "files_written": 1, "tool_calls": 5}
}
JSON
  local input='{"task_subject":"T1: Product Manager","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "blocks when artifact doesn't exist on disk" "2" "$HOOK_EXIT"
  assert_contains "error mentions missing artifact" "$HOOK_STDERR_CONTENT" "artifacts that don't exist"
  cleanup_workspace "$ws"
}

# --- Pass tests (exit 0) ---

test_allows_valid_receipt() {
  local ws; ws=$(create_workspace)
  local receipt_dir="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  local artifact="$ws/Claude-Production-Grade-Suite/product-manager/BRD/brd.md"
  mkdir -p "$(dirname "$artifact")"
  echo "# BRD" > "$artifact"
  cat > "$receipt_dir/T1-product-manager.json" <<JSON
{
  "task_id": "T1",
  "skill": "product-manager",
  "status": "completed",
  "completed_at": "2026-03-15T00:00:00Z",
  "artifacts": ["$artifact"],
  "metrics": {"user_stories": 5, "acceptance_criteria": 12},
  "effort": {"files_read": 3, "files_written": 1, "tool_calls": 10}
}
JSON
  local input='{"task_subject":"T1: Product Manager","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "allows completion with valid receipt" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

test_handles_task_id_with_suffix() {
  local ws; ws=$(create_workspace)
  local receipt_dir="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  cat > "$receipt_dir/T3a-software-engineer.json" <<'JSON'
{
  "task_id": "T3a",
  "skill": "software-engineer",
  "status": "completed",
  "completed_at": "2026-03-15T00:00:00Z",
  "artifacts": [],
  "metrics": {"services": 2},
  "effort": {"files_read": 10, "files_written": 5, "tool_calls": 30}
}
JSON
  local input='{"task_subject":"T3a: Software Engineer","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "handles T3a task ID with letter suffix" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

test_allows_empty_artifacts_array() {
  local ws; ws=$(create_workspace)
  local receipt_dir="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  cat > "$receipt_dir/T10-data-scientist.json" <<'JSON'
{
  "task_id": "T10",
  "skill": "data-scientist",
  "status": "skipped",
  "completed_at": "2026-03-15T00:00:00Z",
  "artifacts": [],
  "metrics": {},
  "effort": {"files_read": 0, "files_written": 0, "tool_calls": 0}
}
JSON
  local input='{"task_subject":"T10: Data Scientist","team_name":"production-grade"}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "allows skipped task with empty artifacts" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_non_production_grade_team
test_guard_no_task_id_in_subject
test_blocks_when_no_receipt
test_blocks_when_receipt_missing_fields
test_blocks_when_effort_subfields_missing
test_blocks_when_artifact_missing_on_disk
test_allows_valid_receipt
test_handles_task_id_with_suffix
test_allows_empty_artifacts_array

print_summary
