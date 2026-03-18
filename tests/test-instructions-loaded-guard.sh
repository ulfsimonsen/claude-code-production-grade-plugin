#!/bin/bash
# Tests for hooks/instructions-loaded-guard.sh (InstructionsLoaded hook)
source "$(dirname "$0")/framework.sh"

HOOK="$HOOKS_DIR/instructions-loaded-guard.sh"
begin_suite "instructions-loaded-guard.sh"

# --- Guard tests ---

test_guard_no_plugin_root() {
  local ws; ws=$(create_workspace)
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && unset CLAUDE_PLUGIN_ROOT && echo '{}' | bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 without CLAUDE_PLUGIN_ROOT" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when no CLAUDE_PLUGIN_ROOT" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_no_plugin_data() {
  local ws; ws=$(create_workspace)
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 without CLAUDE_PLUGIN_DATA" "0" "$HOOK_EXIT"
  assert_eq "guard: no output without CLAUDE_PLUGIN_DATA" "" "$HOOK_OUTPUT"
  cleanup_workspace "$ws"
}

test_guard_no_preferences_file() {
  local ws; ws=$(create_workspace)
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  # data_dir exists but no preferences.json
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "guard: exits 0 when preferences.json missing" "0" "$HOOK_EXIT"
  assert_eq "guard: no output when preferences.json missing" "" "$HOOK_OUTPUT"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

# --- Preference loading ---

test_loads_preferences_and_outputs_json() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  echo '{"engagement":"express","parallelism":"sequential","worktrees":"disabled"}' > "$data_dir/preferences.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  assert_eq "exits 0 with valid preferences" "0" "$HOOK_EXIT"
  echo "$HOOK_OUTPUT" | jq empty 2>/dev/null
  assert_eq "output is valid JSON" "0" "$?"
  local event
  event=$(echo "$HOOK_OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
  assert_eq "hookEventName is InstructionsLoaded" "InstructionsLoaded" "$event"
  assert_contains "context mentions engagement" "$HOOK_OUTPUT" "engagement=express"
  assert_contains "context mentions parallelism" "$HOOK_OUTPUT" "parallelism=sequential"
  assert_contains "context mentions worktrees" "$HOOK_OUTPUT" "worktrees=disabled"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

test_writes_settings_md_when_orch_dir_exists() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  echo '{"engagement":"meticulous","parallelism":"maximum","worktrees":"enabled","effort_level":"high"}' > "$data_dir/preferences.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local settings_file="$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  assert_file_exists "writes settings.md to orchestrator dir" "$settings_file"
  local content
  content=$(cat "$settings_file")
  assert_contains "settings.md has engagement" "$content" "Engagement: meticulous"
  assert_contains "settings.md has parallelism" "$content" "Parallelism: maximum"
  assert_contains "settings.md has worktrees" "$content" "Worktrees: enabled"
  assert_contains "settings.md has effort" "$content" "Effort: high"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

test_does_not_overwrite_existing_settings_md() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  echo "# Existing settings" > "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  echo '{"engagement":"auto"}' > "$data_dir/preferences.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local content
  content=$(cat "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md")
  assert_contains "preserves existing settings.md" "$content" "Existing settings"
  assert_not_contains "does not overwrite with new engagement" "$content" "Engagement: auto"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

test_defaults_when_preferences_empty() {
  local ws; ws=$(create_workspace)
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator"
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  echo '{}' > "$data_dir/preferences.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local settings_file="$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md"
  local content
  content=$(cat "$settings_file")
  assert_contains "defaults engagement to thorough" "$content" "Engagement: thorough"
  assert_contains "defaults parallelism to maximum" "$content" "Parallelism: maximum"
  assert_contains "defaults worktrees to enabled" "$content" "Worktrees: enabled"
  assert_contains "defaults effort to high" "$content" "Effort: high"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

test_no_settings_written_without_orch_dir() {
  local ws; ws=$(create_workspace)
  # orchestrator dir does NOT exist (pipeline not started)
  rm -rf "$ws/Claude-Production-Grade-Suite/.orchestrator"
  mkdir -p "$ws/Claude-Production-Grade-Suite"
  local data_dir
  data_dir=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/plugin-data-XXXXXX")
  echo '{"engagement":"express"}' > "$data_dir/preferences.json"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$ws" && echo '{}' | CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_DATA="$data_dir" bash "$HOOK" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  rm -f "$HOOK_STDERR"
  local has_settings="false"
  [[ -f "$ws/Claude-Production-Grade-Suite/.orchestrator/settings.md" ]] && has_settings="true"
  assert_eq "no settings.md when orchestrator dir missing" "false" "$has_settings"
  rm -rf "$data_dir"
  cleanup_workspace "$ws"
}

# --- Run all tests ---
test_guard_no_plugin_root
test_guard_no_plugin_data
test_guard_no_preferences_file
test_loads_preferences_and_outputs_json
test_writes_settings_md_when_orch_dir_exists
test_does_not_overwrite_existing_settings_md
test_defaults_when_preferences_empty
test_no_settings_written_without_orch_dir

print_summary
