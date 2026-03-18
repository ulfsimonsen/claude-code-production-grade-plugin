#!/bin/bash
# Tests for hooks/hooks.json configuration
source "$(dirname "$0")/framework.sh"

HOOKS_CONFIG="$HOOKS_DIR/hooks.json"
begin_suite "hooks.json"

# --- Valid JSON ---

test_valid_json() {
  assert_json_valid "hooks.json is valid JSON" "$HOOKS_CONFIG"
}

# --- All hook events present ---

test_all_hook_events_present() {
  local expected_events=("SessionStart" "PostCompact" "TeammateIdle" "SubagentStart" "TaskCompleted" "PreCompact" "PreToolUse" "PostToolUse" "StopFailure" "InstructionsLoaded" "WorktreeCreate" "WorktreeRemove" "Stop")
  for event in "${expected_events[@]}"; do
    local exists
    exists=$(jq -r --arg e "$event" '.hooks | has($e)' "$HOOKS_CONFIG")
    assert_eq "hook event '$event' exists" "true" "$exists"
  done
}

# --- All referenced scripts exist on disk ---

test_all_scripts_exist() {
  local scripts
  scripts=$(jq -r '.hooks[][] | .hooks[]? | .command' "$HOOKS_CONFIG" | grep -oE 'hooks/[a-z-]+\.sh' | sort -u)
  local missing=""
  while IFS= read -r script; do
    [[ -z "$script" ]] && continue
    if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
      missing="${missing} ${script}"
    fi
  done <<< "$scripts"
  if [[ -z "$missing" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all referenced scripts exist on disk\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m missing scripts:%s\n" "$missing"
  fi
}

# --- Correct matchers ---

test_preToolUse_matcher() {
  local matcher
  matcher=$(jq -r '.hooks.PreToolUse[0].matcher' "$HOOKS_CONFIG")
  assert_eq "PreToolUse matcher is 'Agent'" "Agent" "$matcher"
}

test_postToolUse_matcher() {
  local matcher
  matcher=$(jq -r '.hooks.PostToolUse[0].matcher' "$HOOKS_CONFIG")
  assert_eq "PostToolUse matcher is 'Write'" "Write" "$matcher"
}

test_subagentStart_matcher_empty() {
  local matcher
  matcher=$(jq -r '.hooks.SubagentStart[0].matcher' "$HOOKS_CONFIG")
  assert_eq "SubagentStart matcher is empty (catch-all)" "" "$matcher"
}

test_taskCompleted_matcher_empty() {
  local matcher
  matcher=$(jq -r '.hooks.TaskCompleted[0].matcher' "$HOOKS_CONFIG")
  assert_eq "TaskCompleted matcher is empty (catch-all)" "" "$matcher"
}

test_preCompact_matcher_empty() {
  local matcher
  matcher=$(jq -r '.hooks.PreCompact[0].matcher' "$HOOKS_CONFIG")
  assert_eq "PreCompact matcher is empty (catch-all)" "" "$matcher"
}

# --- Timeouts ---

test_timeouts_are_reasonable() {
  local max_timeout
  max_timeout=$(jq '[.hooks[][] | .hooks[]? | .timeout // 0] | max' "$HOOKS_CONFIG")
  assert_eq "max timeout is 10s or less" "true" "$( [ "$max_timeout" -le 10 ] && echo true || echo false )"
}

# --- Script commands use CLAUDE_PLUGIN_ROOT guard ---

test_scripts_use_plugin_root_guard() {
  local commands
  commands=$(jq -r '.hooks[][] | .hooks[]? | .command' "$HOOKS_CONFIG")
  local missing=""
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    if [[ "$cmd" != *'CLAUDE_PLUGIN_ROOT'* ]]; then
      missing="${missing} (cmd without PLUGIN_ROOT)"
    fi
  done <<< "$commands"
  if [[ -z "$missing" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all hook commands use CLAUDE_PLUGIN_ROOT guard\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m some commands missing CLAUDE_PLUGIN_ROOT guard\n"
  fi
}

# --- All hooks use type "command" ---

test_all_hooks_type_command() {
  local non_command
  non_command=$(jq '[.hooks[][] | .hooks[]? | .type] | map(select(. != "command")) | length' "$HOOKS_CONFIG")
  assert_eq "all hooks use type 'command'" "0" "$non_command"
}

# --- State validator in PostToolUse ---

test_postToolUse_has_state_validator() {
  local has_validator
  has_validator=$(jq '[.hooks.PostToolUse[0].hooks[] | select(.command | contains("state-validator.sh"))] | length' "$HOOKS_CONFIG")
  assert_eq "PostToolUse Write has state-validator hook" "1" "$has_validator"
}

# --- Hook count ---

test_hook_event_count() {
  local count
  count=$(jq '.hooks | keys | length' "$HOOKS_CONFIG")
  assert_eq "13 hook events defined" "13" "$count"
}

# --- Test runner hook in PostToolUse ---

test_postToolUse_has_test_runner() {
  local has_runner
  has_runner=$(jq '[.hooks.PostToolUse[] | select(.matcher == "Write|Edit") | .hooks[] | select(.command | contains("test-runner.sh"))] | length' "$HOOKS_CONFIG")
  assert_eq "PostToolUse Write|Edit has test-runner hook" "1" "$has_runner"
}

# --- Run all tests ---
test_valid_json
test_all_hook_events_present
test_all_scripts_exist
test_preToolUse_matcher
test_postToolUse_matcher
test_subagentStart_matcher_empty
test_taskCompleted_matcher_empty
test_preCompact_matcher_empty
test_timeouts_are_reasonable
test_scripts_use_plugin_root_guard
test_all_hooks_type_command
test_postToolUse_has_state_validator
test_hook_event_count
test_postToolUse_has_test_runner

print_summary
