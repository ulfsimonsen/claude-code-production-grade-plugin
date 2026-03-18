#!/bin/bash
# Tests for hooks/session-guard.sh (SessionStart hook)
# Extracted from test-pipeline-cleanup.sh + expanded coverage
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/session-guard.sh"
begin_suite "session-guard.sh"

# --- Guard: no suite dir ---

test_guard_no_suite_dir() {
  local ws; ws=$(create_workspace)
  rm -rf "$ws/Claude-Production-Grade-Suite"
  run_hook "$HOOK" '{"source":"startup"}' "$ws"
  assert_eq "guard: exits 0 when no suite dir" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no suite dir" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Cleanup-pending detection ---

test_detects_cleanup_pending_on_startup() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  cat > "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending" <<EOF
# Cleanup Pending — 2026-03-18T10:00:00Z
phase: HARDEN
wave: B
tasks_completed: 5
steps: write-claude-md,team-delete,persist-plugin-data,
EOF
  run_hook "$HOOK" '{"source":"startup"}' "$ws"
  assert_contains "detects cleanup-pending: header" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  assert_contains "detects cleanup-pending: TeamDelete instruction" "$HOOK_OUTPUT" "TeamDelete"
  assert_contains "detects cleanup-pending: MANDATORY label" "$HOOK_OUTPUT" "MANDATORY"
  assert_contains "detects cleanup-pending: shows prior phase" "$HOOK_OUTPUT" "HARDEN"
  assert_contains "detects cleanup-pending: mentions marker deletion" "$HOOK_OUTPUT" "cleanup-pending"
  cleanup_workspace "$ws"
}

test_detects_cleanup_pending_on_resume() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "cleanup marker" > "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending"
  run_hook "$HOOK" '{"source":"resume"}' "$ws"
  assert_contains "detects cleanup-pending on resume" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  cleanup_workspace "$ws"
}

test_no_cleanup_on_clear_source() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "cleanup marker" > "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending"
  run_hook "$HOOK" '{"source":"clear"}' "$ws"
  assert_not_contains "no cleanup output on clear source" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  cleanup_workspace "$ws"
}

test_no_cleanup_when_no_marker() {
  local ws; ws=$(create_workspace)
  run_hook "$HOOK" '{"source":"startup"}' "$ws"
  assert_not_contains "no cleanup output when no marker" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  cleanup_workspace "$ws"
}

# --- Active pipeline re-orientation (clear/resume) ---

test_reorient_on_clear_with_active_pipeline() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "- Engagement: thorough" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  run_hook "$HOOK" '{"source":"clear"}' "$ws"
  assert_contains "reorient on clear: pipeline active header" "$HOOK_OUTPUT" "Pipeline Active"
  assert_contains "reorient on clear: says don't re-prompt" "$HOOK_OUTPUT" "Do not re-prompt"
  assert_contains "reorient on clear: mentions settings.md" "$HOOK_OUTPUT" "settings.md"
  assert_contains "reorient on clear: mentions receipts" "$HOOK_OUTPUT" "receipts"
  cleanup_workspace "$ws"
}

test_reorient_on_resume_with_active_pipeline() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "- Engagement: express" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  run_hook "$HOOK" '{"source":"resume"}' "$ws"
  assert_contains "reorient on resume: pipeline active" "$HOOK_OUTPUT" "Pipeline Active"
  cleanup_workspace "$ws"
}

test_no_reorient_when_pipeline_complete() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "- Engagement: thorough" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  echo "complete" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '{"source":"clear"}' "$ws"
  # Should fall through to the full guard, not show re-orientation
  assert_not_contains "no reorient when complete" "$HOOK_OUTPUT" "Pipeline Active"
  cleanup_workspace "$ws"
}

test_no_reorient_when_pipeline_rejected() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "- Engagement: thorough" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  echo "rejected" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '{"source":"clear"}' "$ws"
  assert_not_contains "no reorient when rejected" "$HOOK_OUTPUT" "Pipeline Active"
  cleanup_workspace "$ws"
}

test_reorient_when_partial_status() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "- Engagement: thorough" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  echo "partial" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  run_hook "$HOOK" '{"source":"clear"}' "$ws"
  assert_contains "reorient when partial status" "$HOOK_OUTPUT" "Pipeline Active"
  cleanup_workspace "$ws"
}

# --- Startup full guard message ---

test_startup_shows_full_guard() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T1-pm.json"
  echo '{}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts/T2-arch.json"
  run_hook "$HOOK" '{"source":"startup"}' "$ws"
  assert_contains "startup: shows native project header" "$HOOK_OUTPUT" "Production-Grade Native Project Detected"
  assert_contains "startup: mentions receipt count" "$HOOK_OUTPUT" "2 pipeline receipts"
  assert_contains "startup: shows Elicitation prompt" "$HOOK_OUTPUT" "How would you like to work today"
  assert_contains "startup: option 1 is production-grade" "$HOOK_OUTPUT" "Use production-grade"
  assert_contains "startup: option 2 is direct work" "$HOOK_OUTPUT" "Work directly"
  assert_contains "startup: option 3 is chat" "$HOOK_OUTPUT" "Chat about this"
  cleanup_workspace "$ws"
}

test_startup_no_settings_falls_through_to_guard() {
  local ws; ws=$(create_workspace)
  # Suite dir exists but no settings.md and no cleanup-pending
  run_hook "$HOOK" '{"source":"startup"}' "$ws"
  assert_contains "startup without settings shows guard" "$HOOK_OUTPUT" "Production-Grade Native"
  cleanup_workspace "$ws"
}

# --- Returning user detection ---

test_returning_user_with_preferences() {
  local ws; ws=$(create_workspace)
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  echo '{"engagement":"express"}' > "$data_dir/preferences.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{"source":"startup"}' | CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "returning user: mentions saved preferences" "$HOOK_OUTPUT" "saved preferences"
  assert_contains "returning user: mentions auto-applied" "$HOOK_OUTPUT" "auto-applied"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_suite_dir
test_detects_cleanup_pending_on_startup
test_detects_cleanup_pending_on_resume
test_no_cleanup_on_clear_source
test_no_cleanup_when_no_marker
test_reorient_on_clear_with_active_pipeline
test_reorient_on_resume_with_active_pipeline
test_no_reorient_when_pipeline_complete
test_no_reorient_when_pipeline_rejected
test_reorient_when_partial_status
test_startup_shows_full_guard
test_startup_no_settings_falls_through_to_guard
test_returning_user_with_preferences

print_summary
