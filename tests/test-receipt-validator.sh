#!/bin/bash
# Tests for hooks/receipt-validator.sh (PostToolUse Write hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/receipt-validator.sh"
begin_suite "receipt-validator.sh"

# --- Guard tests ---

test_guard_non_receipt_path() {
  local ws; ws=$(create_workspace)
  local input='{"tool_input":{"file_path":"/some/other/file.json"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "guard: exits 0 for non-receipt path" "0" "$HOOK_EXIT"
  assert_eq "guard: no output for non-receipt path" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_non_json_receipt() {
  local ws; ws=$(create_workspace)
  local input='{"tool_input":{"file_path":"/some/receipts/file.txt"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "guard: exits 0 for non-.json in receipts dir" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

test_guard_missing_file() {
  local ws; ws=$(create_workspace)
  local input='{"tool_input":{"file_path":"'$ws'/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-missing.json"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "guard: exits 0 when receipt file doesn't exist on disk" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

test_guard_no_task_id_in_filename() {
  local ws; ws=$(create_workspace)
  local receipt="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/random-name.json"
  echo '{}' > "$receipt"
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "guard: exits 0 when filename has no task ID" "0" "$HOOK_EXIT"
  cleanup_workspace "$ws"
}

# --- Validation tests ---

write_receipt() {
  local ws="$1" task_id="$2" skill="$3" content="$4"
  local receipt="$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/${task_id}-${skill}.json"
  echo "$content" > "$receipt"
  echo "$receipt"
}

test_rejects_missing_task_id() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {},
    "effort": {"files_read": 1, "files_written": 1, "tool_calls": 5}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects receipt missing task_id" "$HOOK_OUTPUT" "missing:task_id"
  cleanup_workspace "$ws"
}

test_rejects_missing_effort() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects receipt missing effort" "$HOOK_OUTPUT" "missing:effort"
  cleanup_workspace "$ws"
}

test_rejects_missing_effort_subfields() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {},
    "effort": {"files_read": 1}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects receipt missing effort.files_written" "$HOOK_OUTPUT" "missing:effort.files_written"
  assert_contains "rejects receipt missing effort.tool_calls" "$HOOK_OUTPUT" "missing:effort.tool_calls"
  cleanup_workspace "$ws"
}

test_rejects_invalid_status() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "running",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {},
    "effort": {"files_read": 1, "files_written": 1, "tool_calls": 5}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects invalid status 'running'" "$HOOK_OUTPUT" "invalid_status:running"
  cleanup_workspace "$ws"
}

test_accepts_valid_status_completed() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T2" "solution-architect" '{
    "task_id": "T2",
    "skill": "solution-architect",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {"adrs": 3, "endpoints": 10},
    "effort": {"files_read": 5, "files_written": 3, "tool_calls": 20}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run_hook "$HOOK" "$input" "$ws"
  assert_eq "accepts status 'completed'" "0" "$HOOK_EXIT"
  assert_not_contains "no validation error for 'completed'" "$HOOK_OUTPUT" "RECEIPT VALIDATION FAILED"
  cleanup_workspace "$ws"
}

test_accepts_valid_status_failed() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T2" "solution-architect" '{
    "task_id": "T2",
    "skill": "solution-architect",
    "status": "failed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {},
    "effort": {"files_read": 5, "files_written": 0, "tool_calls": 10}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_not_contains "accepts status 'failed'" "$HOOK_OUTPUT" "invalid_status"
  cleanup_workspace "$ws"
}

test_accepts_valid_status_skipped() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T10" "data-scientist" '{
    "task_id": "T10",
    "skill": "data-scientist",
    "status": "skipped",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {},
    "effort": {"files_read": 0, "files_written": 0, "tool_calls": 0}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_not_contains "accepts status 'skipped'" "$HOOK_OUTPUT" "invalid_status"
  cleanup_workspace "$ws"
}

test_rejects_missing_artifact() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": ["/nonexistent/path/brd.md"],
    "metrics": {},
    "effort": {"files_read": 1, "files_written": 1, "tool_calls": 5}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects when artifact path doesn't exist" "$HOOK_OUTPUT" "artifact_missing:/nonexistent/path/brd.md"
  cleanup_workspace "$ws"
}

test_accepts_existing_artifact() {
  local ws; ws=$(create_workspace)
  local artifact_file="$ws/Claude-Production-Grade-Suite/product-manager/BRD/brd.md"
  mkdir -p "$(dirname "$artifact_file")"
  echo "# BRD" > "$artifact_file"
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": ["'"$artifact_file"'"],
    "metrics": {},
    "effort": {"files_read": 3, "files_written": 1, "tool_calls": 10}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_eq "accepts receipt with existing artifact" "0" "$HOOK_EXIT"
  assert_not_contains "no artifact_missing error" "$HOOK_OUTPUT" "artifact_missing"
  cleanup_workspace "$ws"
}

test_accepts_artifact_directory() {
  local ws; ws=$(create_workspace)
  local artifact_dir="$ws/Claude-Production-Grade-Suite/product-manager/BRD"
  mkdir -p "$artifact_dir"
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": ["'"$artifact_dir"'"],
    "metrics": {},
    "effort": {"files_read": 3, "files_written": 1, "tool_calls": 10}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  assert_not_contains "accepts directory as artifact" "$HOOK_OUTPUT" "artifact_missing"
  cleanup_workspace "$ws"
}

# --- Task-specific schema validation ---

test_rejects_missing_required_metric() {
  local ws; ws=$(create_workspace)
  # T1 schema requires metrics: user_stories, acceptance_criteria
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {"user_stories": 5},
    "effort": {"files_read": 3, "files_written": 1, "tool_calls": 10}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects missing required metric (acceptance_criteria)" "$HOOK_OUTPUT" "missing_metric:acceptance_criteria"
  cleanup_workspace "$ws"
}

test_rejects_metric_below_min_value() {
  local ws; ws=$(create_workspace)
  # T1 schema has min_values: user_stories >= 1
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {"user_stories": 0, "acceptance_criteria": 3},
    "effort": {"files_read": 3, "files_written": 1, "tool_calls": 10}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run_hook "$HOOK" "$input" "$ws"
  assert_contains "rejects metric below min_value" "$HOOK_OUTPUT" "below_min:user_stories"
  cleanup_workspace "$ws"
}

test_accepts_metrics_at_minimum() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T1" "product-manager" '{
    "task_id": "T1",
    "skill": "product-manager",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {"user_stories": 1, "acceptance_criteria": 1},
    "effort": {"files_read": 3, "files_written": 1, "tool_calls": 10}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run_hook "$HOOK" "$input" "$ws"
  assert_eq "accepts metrics at minimum values" "0" "$HOOK_EXIT"
  assert_not_contains "no below_min error" "$HOOK_OUTPUT" "below_min"
  cleanup_workspace "$ws"
}

# --- state.json update on success ---

test_updates_state_json_on_valid_receipt() {
  local ws; ws=$(create_workspace)
  local state_file="$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo '{"current_phase":"BUILD","tasks_completed":["T1"]}' > "$state_file"
  local receipt
  receipt=$(write_receipt "$ws" "T2" "solution-architect" '{
    "task_id": "T2",
    "skill": "solution-architect",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {"adrs": 3, "endpoints": 10},
    "effort": {"files_read": 5, "files_written": 3, "tool_calls": 20}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run_hook "$HOOK" "$input" "$ws"
  assert_eq "exits 0 for valid receipt" "0" "$HOOK_EXIT"
  # Check state.json was updated
  local completed
  completed=$(jq -r '.tasks_completed | sort | join(",")' "$state_file")
  assert_eq "state.json updated with T2 in tasks_completed" "T1,T2" "$completed"
  cleanup_workspace "$ws"
}

test_no_duplicate_in_state_json() {
  local ws; ws=$(create_workspace)
  local state_file="$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo '{"current_phase":"BUILD","tasks_completed":["T1","T2"]}' > "$state_file"
  local receipt
  receipt=$(write_receipt "$ws" "T2" "solution-architect" '{
    "task_id": "T2",
    "skill": "solution-architect",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {},
    "effort": {"files_read": 5, "files_written": 3, "tool_calls": 20}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  run_hook "$HOOK" "$input" "$ws"
  local count
  count=$(jq '.tasks_completed | length' "$state_file")
  assert_eq "no duplicate T2 in tasks_completed" "2" "$count"
  cleanup_workspace "$ws"
}

# --- T3a task ID with suffix ---

test_extracts_task_id_with_letter_suffix() {
  local ws; ws=$(create_workspace)
  local receipt
  receipt=$(write_receipt "$ws" "T3a" "software-engineer" '{
    "task_id": "T3a",
    "skill": "software-engineer",
    "status": "completed",
    "completed_at": "2026-03-15T00:00:00Z",
    "artifacts": [],
    "metrics": {"services": 2, "endpoints": 8},
    "effort": {"files_read": 10, "files_written": 5, "tool_calls": 30}
  }')
  local input='{"tool_input":{"file_path":"'"$receipt"'"}}'
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run_hook "$HOOK" "$input" "$ws"
  assert_eq "correctly handles T3a task ID" "0" "$HOOK_EXIT"
  assert_not_contains "no validation errors for T3a" "$HOOK_OUTPUT" "RECEIPT VALIDATION FAILED"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_non_receipt_path
test_guard_non_json_receipt
test_guard_missing_file
test_guard_no_task_id_in_filename
test_rejects_missing_task_id
test_rejects_missing_effort
test_rejects_missing_effort_subfields
test_rejects_invalid_status
test_accepts_valid_status_completed
test_accepts_valid_status_failed
test_accepts_valid_status_skipped
test_rejects_missing_artifact
test_accepts_existing_artifact
test_accepts_artifact_directory
test_rejects_missing_required_metric
test_rejects_metric_below_min_value
test_accepts_metrics_at_minimum
test_updates_state_json_on_valid_receipt
test_no_duplicate_in_state_json
test_extracts_task_id_with_letter_suffix

print_summary
