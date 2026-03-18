#!/bin/bash
# Tests for skills/production-grade/phases/critical/*.txt (Layer 2)
# Verifies critical directive files exist and contain expected mandatory steps.
source "$(dirname "$0")/framework.sh"

CRITICAL_DIR="$PROJECT_ROOT/skills/production-grade/phases/critical"
begin_suite "critical-directives"

# --- File existence ---

test_all_five_files_exist() {
  local phases=("define" "build" "harden" "ship" "sustain")
  for phase in "${phases[@]}"; do
    assert_file_exists "${phase}-critical.txt exists" "$CRITICAL_DIR/${phase}-critical.txt"
  done
}

# --- Content: mandatory keywords per phase ---

test_define_critical_content() {
  local content
  content=$(cat "$CRITICAL_DIR/define-critical.txt")
  assert_contains "define: mentions Gate 1" "$content" "Gate 1"
  assert_contains "define: mentions Gate 2" "$content" "Gate 2"
  assert_contains "define: mentions re-anchor" "$content" "e-anchor"
  assert_contains "define: mentions BUILD handoff" "$content" "BUILD"
}

test_build_critical_content() {
  local content
  content=$(cat "$CRITICAL_DIR/build-critical.txt")
  assert_contains "build: mentions worktree" "$content" "orktree"
  assert_contains "build: mentions merge-back" "$content" "erge-back"
  assert_contains "build: mentions agent list" "$content" "T3a"
  assert_contains "build: mentions HARDEN handoff" "$content" "HARDEN"
}

test_harden_critical_content() {
  local content
  content=$(cat "$CRITICAL_DIR/harden-critical.txt")
  assert_contains "harden: mentions authority boundaries" "$content" "uthority"
  assert_contains "harden: mentions readiness check" "$content" "eadiness"
  assert_contains "harden: mentions SHIP handoff" "$content" "SHIP"
}

test_ship_critical_content() {
  local content
  content=$(cat "$CRITICAL_DIR/ship-critical.txt")
  assert_contains "ship: mentions Gate 3" "$content" "Gate 3"
  assert_contains "ship: mentions remediation" "$content" "emediation"
  assert_contains "ship: mentions SUSTAIN handoff" "$content" "SUSTAIN"
}

test_sustain_critical_content() {
  local content
  content=$(cat "$CRITICAL_DIR/sustain-critical.txt")
  assert_contains "sustain: mentions TeamDelete" "$content" "TeamDelete"
  assert_contains "sustain: mentions pipeline-status" "$content" "pipeline-status"
  assert_contains "sustain: mentions CLAUDE.md" "$content" "CLAUDE.md"
  assert_contains "sustain: mentions CLAUDE_PLUGIN_DATA" "$content" "CLAUDE_PLUGIN_DATA"
}

# --- Size constraints: should be compact (under 20 lines) ---

test_files_are_compact() {
  local phases=("define" "build" "harden" "ship" "sustain")
  for phase in "${phases[@]}"; do
    local lines
    lines=$(wc -l < "$CRITICAL_DIR/${phase}-critical.txt" | tr -d ' ')
    local ok="true"
    [[ "$lines" -gt 20 ]] && ok="false"
    assert_eq "${phase}-critical.txt is compact (<= 20 lines, got ${lines})" "true" "$ok"
  done
}

# --- No file is empty ---

test_files_are_not_empty() {
  local phases=("define" "build" "harden" "ship" "sustain")
  for phase in "${phases[@]}"; do
    local size
    size=$(wc -c < "$CRITICAL_DIR/${phase}-critical.txt" | tr -d ' ')
    local ok="true"
    [[ "$size" -lt 50 ]] && ok="false"
    assert_eq "${phase}-critical.txt is not empty (>= 50 bytes, got ${size})" "true" "$ok"
  done
}

# --- Run all tests ---
test_all_five_files_exist
test_define_critical_content
test_build_critical_content
test_harden_critical_content
test_ship_critical_content
test_sustain_critical_content
test_files_are_compact
test_files_are_not_empty

print_summary
