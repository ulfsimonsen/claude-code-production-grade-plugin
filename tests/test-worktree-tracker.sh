#!/bin/bash
# Tests for hooks/worktree-create-tracker.sh and hooks/worktree-remove-tracker.sh
source "$(dirname "$0")/framework.sh"

CREATE_HOOK="$HOOKS_DIR/worktree-create-tracker.sh"
REMOVE_HOOK="$HOOKS_DIR/worktree-remove-tracker.sh"
begin_suite "worktree-create-tracker.sh / worktree-remove-tracker.sh"

# --- Guard tests (create) ---

test_create_guard_no_plugin_root() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && unset CLAUDE_PLUGIN_ROOT && echo '{"worktree_path":"/tmp/wt1","branch":"feat-1"}' | bash "$CREATE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "create guard: exits 0 without CLAUDE_PLUGIN_ROOT" "0" "$HOOK_EXIT"
  assert_eq "create guard: no output without CLAUDE_PLUGIN_ROOT" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_create_guard_no_state_file() {
  local ws; ws=$(create_workspace)
  rm -f "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{"worktree_path":"/tmp/wt1"}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$CREATE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "create guard: exits 0 without state.json" "0" "$HOOK_EXIT"
  assert_eq "create guard: no output without state.json" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_create_guard_no_worktree_path() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$CREATE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "create guard: exits 0 when no worktree_path" "0" "$HOOK_EXIT"
  assert_eq "create guard: no output when no worktree_path" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Create tracking ---

test_create_adds_worktree_to_state() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"worktree_path":"/tmp/wt-build","branch":"pg/build-wave-a"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$CREATE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0 on create" "0" "$HOOK_EXIT"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "create output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is WorktreeCreate" "WorktreeCreate" "$event"
  # Check state.json was updated
  local state="$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local wt_path
  wt_path=$(jq -r '.active_worktrees[0].path' "$state")
  assert_eq "state has worktree path" "/tmp/wt-build" "$wt_path"
  local wt_branch
  wt_branch=$(jq -r '.active_worktrees[0].branch' "$state")
  assert_eq "state has worktree branch" "pg/build-wave-a" "$wt_branch"
  local wt_ts
  wt_ts=$(jq -r '.active_worktrees[0].created_at' "$state")
  assert_contains "state has created_at timestamp" "$wt_ts" "T"
  cleanup_workspace "$ws"
}

test_create_no_duplicates() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"worktree_path":"/tmp/wt-same","branch":"feat-1"}'
  # First call
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$CREATE_HOOK" 2>"$HOOK_STDERR" >/dev/null
  rm -f "$HOOK_STDERR"
  # Second call with same path
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$CREATE_HOOK" 2>"$HOOK_STDERR" >/dev/null
  rm -f "$HOOK_STDERR"
  local count
  count=$(jq '.active_worktrees | length' "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json")
  assert_eq "no duplicate worktree entries" "1" "$count"
  cleanup_workspace "$ws"
}

# --- Guard tests (remove) ---

test_remove_guard_no_plugin_root() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","active_worktrees":[{"path":"/tmp/wt1"}]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && unset CLAUDE_PLUGIN_ROOT && echo '{"worktree_path":"/tmp/wt1"}' | bash "$REMOVE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "remove guard: exits 0 without CLAUDE_PLUGIN_ROOT" "0" "$HOOK_EXIT"
  assert_eq "remove guard: no output without CLAUDE_PLUGIN_ROOT" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

# --- Remove tracking ---

test_remove_removes_worktree_from_state() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","active_worktrees":[{"path":"/tmp/wt-a","branch":"a"},{"path":"/tmp/wt-b","branch":"b"}]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"worktree_path":"/tmp/wt-a","branch":"a"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$REMOVE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0 on remove" "0" "$HOOK_EXIT"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "remove output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is WorktreeRemove" "WorktreeRemove" "$event"
  # Check state.json was updated
  local state="$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local count
  count=$(jq '.active_worktrees | length' "$state")
  assert_eq "one worktree remains" "1" "$count"
  local remaining
  remaining=$(jq -r '.active_worktrees[0].path' "$state")
  assert_eq "remaining worktree is wt-b" "/tmp/wt-b" "$remaining"
  cleanup_workspace "$ws"
}

test_remove_handles_nonexistent_path() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD","active_worktrees":[{"path":"/tmp/wt-x","branch":"x"}]}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  local input='{"worktree_path":"/tmp/nonexistent"}'
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo "$input" | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$REMOVE_HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0 when removing nonexistent path" "0" "$HOOK_EXIT"
  # Original worktree should still be there
  local count
  count=$(jq '.active_worktrees | length' "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json")
  assert_eq "original worktree preserved" "1" "$count"
  cleanup_workspace "$ws"
}

# --- Create + Remove round-trip ---

test_create_then_remove_round_trip() {
  local ws; ws=$(create_workspace)
  echo '{"current_phase":"BUILD"}' > "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json"
  # Create
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  cd "$ws" && echo '{"worktree_path":"/tmp/wt-round","branch":"round"}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$CREATE_HOOK" 2>"$HOOK_STDERR" >/dev/null
  rm -f "$HOOK_STDERR"
  local after_create
  after_create=$(jq '.active_worktrees | length' "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json")
  assert_eq "1 worktree after create" "1" "$after_create"
  # Remove
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  cd "$ws" && echo '{"worktree_path":"/tmp/wt-round"}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "$REMOVE_HOOK" 2>"$HOOK_STDERR" >/dev/null
  rm -f "$HOOK_STDERR"
  local after_remove
  after_remove=$(jq '.active_worktrees | length' "$ws/Claude-Production-Grade-Suite/.orchestrator/state.json")
  assert_eq "0 worktrees after remove" "0" "$after_remove"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_create_guard_no_plugin_root
test_create_guard_no_state_file
test_create_guard_no_worktree_path
test_create_adds_worktree_to_state
test_create_no_duplicates
test_remove_guard_no_plugin_root
test_remove_removes_worktree_from_state
test_remove_handles_nonexistent_path
test_create_then_remove_round_trip

print_summary
