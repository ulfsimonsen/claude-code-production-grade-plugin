#!/bin/bash
# Tests for hooks/post-compact-guard.sh (PostCompact hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/post-compact-guard.sh"
begin_suite "post-compact-guard.sh"

# --- Guard tests ---

test_guard_no_suite_dir() {
  local ws; ws=$(create_workspace)
  rm -rf "$ws/Claude-Production-Grade-Suite"
  run_hook "$HOOK" '' "$ws"
  assert_eq "guard: exits 0 when no suite dir" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no suite dir" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_pipeline_complete() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "complete" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '' "$ws"
  assert_eq "guard: exits 0 when pipeline complete" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when pipeline complete" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_pipeline_rejected() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "rejected" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '' "$ws"
  assert_eq "guard: exits 0 when pipeline rejected" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when pipeline rejected" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_no_settings_md() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  # No settings.md → pipeline not started
  run_hook "$HOOK" '' "$ws"
  assert_eq "guard: exits 0 when no settings.md" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no settings.md" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Re-orientation output ---

test_outputs_reorientation_for_active_pipeline() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  cat > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md" <<EOF
# Pipeline Settings
- Engagement: thorough
- Parallelism: maximum
- Worktrees: enabled
EOF
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T2-solution-architect.json"
  run_hook "$HOOK" '' "$ws"
  assert_eq "exits 0 for active pipeline" "0" "$HOOK_EXIT"
  assert_contains "output has re-orientation header" "$HOOK_OUTPUT" "Post-Compaction Re-Orientation"
  assert_contains "output has receipt count" "$HOOK_OUTPUT" "2 completed"
  assert_contains "output mentions settings" "$HOOK_OUTPUT" "thorough engagement"
  assert_contains "output has re-anchor section" "$HOOK_OUTPUT" "Re-Anchor From Disk"
  assert_contains "output says continue pipeline" "$HOOK_OUTPUT" "Continue the pipeline"
  assert_contains "output says do not restart" "$HOOK_OUTPUT" "Do not restart"
  cleanup_workspace "$ws"
}

test_detects_wave_from_receipts_define() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo "- Engagement: standard" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json"
  run_hook "$HOOK" '' "$ws"
  assert_contains "detects DEFINE (BRD complete)" "$HOOK_OUTPUT" "DEFINE (BRD complete)"
  assert_contains "next dispatcher is define.md" "$HOOK_OUTPUT" "define.md"
  cleanup_workspace "$ws"
}

test_detects_wave_a_from_receipts() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo "- Engagement: standard" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T2-solution-architect.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T3a-software-engineer.json"
  run_hook "$HOOK" '' "$ws"
  assert_contains "detects Wave A" "$HOOK_OUTPUT" "Wave A"
  assert_contains "next dispatcher is harden" "$HOOK_OUTPUT" "harden.md"
  cleanup_workspace "$ws"
}

test_detects_wave_starting() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo "- Engagement: standard" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  # No receipts
  run_hook "$HOOK" '' "$ws"
  assert_contains "detects DEFINE (starting)" "$HOOK_OUTPUT" "DEFINE (starting)"
  cleanup_workspace "$ws"
}

test_detects_rework_pending() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo "- Engagement: standard" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  cat > "$ws/Claude-Production-Grade-Suite/.orchestrator/rework-log.md" <<EOF
## Gate 1 — Rework
Some issues found.
## Gate 2 — Rework
More issues.
EOF
  run_hook "$HOOK" '' "$ws"
  assert_contains "detects rework cycles" "$HOOK_OUTPUT" "rework log"
  cleanup_workspace "$ws"
}

test_partial_status_does_not_block() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo "- Engagement: express" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  echo "partial" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '' "$ws"
  assert_contains "partial status still outputs re-orientation" "$HOOK_OUTPUT" "Post-Compaction Re-Orientation"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_suite_dir
test_guard_pipeline_complete
test_guard_pipeline_rejected
test_guard_no_settings_md
test_outputs_reorientation_for_active_pipeline
test_detects_wave_from_receipts_define
test_detects_wave_a_from_receipts
test_detects_wave_starting
test_detects_rework_pending
test_partial_status_does_not_block

print_summary
