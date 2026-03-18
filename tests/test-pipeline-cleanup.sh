#!/bin/bash
# Tests for hooks/pipeline-cleanup.sh (Stop hook) and
# session-guard.sh cleanup-pending detection (Layer 4 read side)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/pipeline-cleanup.sh"
GUARD_HOOK="$HOOKS_DIR/session-guard.sh"
begin_suite "pipeline-cleanup.sh"

# --- Guard tests ---

test_guard_no_plugin_root() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && unset CLAUDE_PLUGIN_ROOT && echo '{}' | bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 without CLAUDE_PLUGIN_ROOT" "0" "$HOOK_EXIT"
  # Verify no side effects
  local has_marker="false"
  [[ -f "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status" ]] && has_marker="true"
  assert_eq "guard: no partial marker written" "false" "$has_marker"
  cleanup_workspace "$ws"
}

test_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 without state.json" "0" "$HOOK_EXIT"
  # Verify no side effects
  local has_marker="false"
  [[ -f "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status" ]] && has_marker="true"
  assert_eq "guard: no partial marker written without state.json" "false" "$has_marker"
  cleanup_workspace "$ws"
}

test_guard_already_complete() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"COMPLETE","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "complete" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 when already complete" "0" "$HOOK_EXIT"
  # Verify pipeline-status was NOT overwritten to "partial"
  local status
  status=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status")
  assert_eq "guard: doesn't overwrite 'complete' to 'partial'" "complete" "$status"
  # Verify no cleanup-pending marker
  local has_cleanup="false"
  [[ -f "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending" ]] && has_cleanup="true"
  assert_eq "guard: no cleanup-pending when already complete" "false" "$has_cleanup"
  cleanup_workspace "$ws"
}

test_guard_already_rejected() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"DEFINE","phase_file_loaded":true}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  echo "rejected" > "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 when rejected" "0" "$HOOK_EXIT"
  local status
  status=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status")
  assert_eq "guard: doesn't overwrite 'rejected'" "rejected" "$status"
  cleanup_workspace "$ws"
}

# --- Partial marker and cleanup-pending tests ---

test_writes_partial_marker() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"tasks_completed":["T1","T2"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_file_exists "writes partial marker" "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status"
  local status
  status=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/pipeline-status")
  assert_eq "partial marker contains 'partial'" "partial" "$status"
  cleanup_workspace "$ws"
}

test_writes_cleanup_pending_marker() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"HARDEN","phase_file_loaded":true,"tasks_completed":["T1","T2","T3a"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_file_exists "writes cleanup-pending marker" "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending"
  local content
  content=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending")
  assert_contains "cleanup-pending includes team-delete step" "$content" "team-delete"
  assert_contains "cleanup-pending includes phase info" "$content" "HARDEN"
  assert_contains "cleanup-pending includes persist-plugin-data" "$content" "persist-plugin-data"
  cleanup_workspace "$ws"
}

test_cleanup_pending_includes_claude_md_step_when_missing() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SUSTAIN","phase_file_loaded":true,"tasks_completed":["T1"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # No CLAUDE.md exists
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local content
  content=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending")
  assert_contains "includes write-claude-md when CLAUDE.md missing" "$content" "write-claude-md"
  cleanup_workspace "$ws"
}

test_cleanup_pending_omits_claude_md_step_when_present() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"SUSTAIN","phase_file_loaded":true,"tasks_completed":["T1"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # Create CLAUDE.md with the directive
  echo "# Production Grade Native" > "$ws/CLAUDE.md"
  echo "This project was built with the production-grade plugin." >> "$ws/CLAUDE.md"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local content
  content=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending")
  assert_not_contains "omits write-claude-md when directive already present" "$content" "write-claude-md"
  cleanup_workspace "$ws"
}

test_logs_stop_event() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"tasks_completed":["T1"]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_file_exists "writes error log" "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md"
  local log
  log=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/error-log.md")
  assert_contains "log includes SessionStop" "$log" "SessionStop"
  assert_contains "log includes phase" "$log" "BUILD"
  cleanup_workspace "$ws"
}

# --- Output format ---

test_output_is_valid_json() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","phase_file_loaded":true,"tasks_completed":[]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is Stop" "Stop" "$event"
  assert_contains "output mentions cleanup steps" "$HOOK_OUTPUT" "Cleanup-pending"
  cleanup_workspace "$ws"
}

# --- Layer 4 read side: session-guard.sh cleanup-pending detection ---

test_session_guard_detects_cleanup_pending_on_startup() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  # Write a cleanup-pending marker (as if pipeline-cleanup.sh left it)
  cat > "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending" <<EOF
# Cleanup Pending — 2026-03-18T10:00:00Z
phase: HARDEN
wave: B
tasks_completed: 5
steps: write-claude-md,team-delete,persist-plugin-data,
EOF
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{"source":"startup"}' | bash "$GUARD_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "guard detects cleanup-pending: TeamDelete instruction" "$HOOK_OUTPUT" "TeamDelete"
  assert_contains "guard detects cleanup-pending: MANDATORY label" "$HOOK_OUTPUT" "MANDATORY"
  assert_contains "guard detects cleanup-pending: shows prior phase" "$HOOK_OUTPUT" "HARDEN"
  cleanup_workspace "$ws"
}

test_session_guard_detects_cleanup_pending_on_resume() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "cleanup marker" > "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{"source":"resume"}' | bash "$GUARD_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_contains "guard detects cleanup-pending on resume" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  cleanup_workspace "$ws"
}

test_session_guard_no_cleanup_when_no_marker() {
  local ws; ws=$(create_workspace)
  # No cleanup-pending file — should NOT output cleanup instructions
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{"source":"startup"}' | bash "$GUARD_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_not_contains "no cleanup output when no marker" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  cleanup_workspace "$ws"
}

test_session_guard_no_cleanup_on_clear() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "cleanup marker" > "$ws/Claude-Production-Grade-Suite/.orchestrator/cleanup-pending"
  # "clear" source should NOT trigger cleanup detection (only startup/resume)
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{"source":"clear"}' | bash "$GUARD_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_not_contains "no cleanup on clear source" "$HOOK_OUTPUT" "Pipeline Cleanup Required"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_plugin_root
test_guard_no_state_file
test_guard_already_complete
test_guard_already_rejected
test_writes_partial_marker
test_writes_cleanup_pending_marker
test_cleanup_pending_includes_claude_md_step_when_missing
test_cleanup_pending_omits_claude_md_step_when_present
test_logs_stop_event
test_output_is_valid_json
test_session_guard_detects_cleanup_pending_on_startup
test_session_guard_detects_cleanup_pending_on_resume
test_session_guard_no_cleanup_when_no_marker
test_session_guard_no_cleanup_on_clear

print_summary
