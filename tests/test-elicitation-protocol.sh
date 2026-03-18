#!/bin/bash
# Tests for elicitation protocol migration and ux-protocol.md pointer
# Validates that v7.0.0 Elicitation migration is structurally consistent
source "$(dirname "$0")/framework.sh"

PROTOCOLS_DIR="$PROJECT_ROOT/skills/_shared/protocols"
ELICITATION_FILE="$PROTOCOLS_DIR/elicitation-protocol.md"
UX_FILE="$PROTOCOLS_DIR/ux-protocol.md"

begin_suite "Elicitation Protocol"

# Helper: check if a file contains a string (grep-based)
assert_file_contains() {
  local desc="$1" file="$2" needle="$3"
  ((_TOTAL++))
  if grep -qF "$needle" "$file" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    '%s' not found in %s\n" "$needle" "$(basename "$file")"
  fi
}

# Helper: check that a file does NOT contain a string
assert_file_not_contains() {
  local desc="$1" file="$2" needle="$3"
  ((_TOTAL++))
  if ! grep -qF "$needle" "$file" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    '%s' should not appear in %s\n" "$needle" "$(basename "$file")"
  fi
}

# ─── elicitation-protocol.md exists ───

test_elicitation_protocol_exists() {
  assert_file_exists "elicitation-protocol.md exists in skills/_shared/protocols/" \
    "$ELICITATION_FILE"
}

# ─── elicitation-protocol.md uses Elicitation (not AskUserQuestion) for instructions ───

test_elicitation_protocol_uses_elicitation_tool() {
  assert_file_contains "elicitation-protocol.md references MCP Elicitation tool" \
    "$ELICITATION_FILE" "MCP Elicitation"
}

test_elicitation_protocol_has_rule1() {
  assert_file_contains "elicitation-protocol.md has RULE 1 for structured input" \
    "$ELICITATION_FILE" "RULE 1"
}

test_elicitation_protocol_has_auto_mode_section() {
  assert_file_contains "elicitation-protocol.md documents Auto mode zero-elicitation rule" \
    "$ELICITATION_FILE" "Auto mode"
}

test_elicitation_protocol_has_mapping_guide() {
  assert_file_contains "elicitation-protocol.md has AskUserQuestion migration mapping guide" \
    "$ELICITATION_FILE" "AskUserQuestion"
}

test_elicitation_protocol_has_escape_hatch() {
  assert_file_contains "elicitation-protocol.md documents escape hatch for free-form input" \
    "$ELICITATION_FILE" "escape hatch"
}

# ─── ux-protocol.md has pointer to elicitation-protocol.md ───

test_ux_protocol_has_elicitation_pointer() {
  assert_file_contains "ux-protocol.md has pointer to elicitation-protocol.md" \
    "$UX_FILE" "elicitation-protocol.md"
}

# ─── ux-protocol.md still has Auto mode engagement table (not fully removed) ───

test_ux_protocol_has_auto_engagement_row() {
  assert_file_contains "ux-protocol.md has Auto row in engagement table" \
    "$UX_FILE" "| **Auto**"
}

test_ux_protocol_auto_zero_calls() {
  assert_file_contains "ux-protocol.md Auto row says ZERO AskUserQuestion calls" \
    "$UX_FILE" "ZERO AskUserQuestion calls"
}

test_ux_protocol_auto_vs_express_section() {
  assert_file_contains "ux-protocol.md documents Auto vs Express differences" \
    "$UX_FILE" "What Auto mode changes vs Express"
}

# ─── elicitation-protocol.md mode table has Auto at zero calls ───

test_elicitation_auto_mode_zero_calls() {
  assert_file_contains "elicitation-protocol.md Auto mode row shows zero Elicitation calls" \
    "$ELICITATION_FILE" "Zero Elicitation calls"
}

# ─── elicitation-protocol.md documents recommended option pattern ───

test_elicitation_recommended_pattern() {
  assert_file_contains "elicitation-protocol.md documents Recommended option pattern" \
    "$ELICITATION_FILE" "Recommended"
}

# ─── Run all tests ───
test_elicitation_protocol_exists
test_elicitation_protocol_uses_elicitation_tool
test_elicitation_protocol_has_rule1
test_elicitation_protocol_has_auto_mode_section
test_elicitation_protocol_has_mapping_guide
test_elicitation_protocol_has_escape_hatch
test_ux_protocol_has_elicitation_pointer
test_ux_protocol_has_auto_engagement_row
test_ux_protocol_auto_zero_calls
test_ux_protocol_auto_vs_express_section
test_elicitation_auto_mode_zero_calls
test_elicitation_recommended_pattern

print_summary
