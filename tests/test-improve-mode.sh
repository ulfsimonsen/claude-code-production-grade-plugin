#!/bin/bash
# Tests for Improve mode structural consistency across skill/phase/schema files
# Validates that Improve mode instructions, schemas, and agent definitions are complete
source "$(dirname "$0")/framework.sh"

SKILLS_DIR="$PROJECT_ROOT/skills/production-grade"
PHASES_DIR="$SKILLS_DIR/phases"
SCHEMAS_DIR="$SKILLS_DIR/schemas"
EVALUATOR_DIR="$PROJECT_ROOT/skills/evaluator"

begin_suite "Improve Mode — Structural Consistency"

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

# ─── Required files exist ───

test_improve_md_exists() {
  assert_file_exists "improve.md exists in skills/production-grade/phases/" \
    "$PHASES_DIR/improve.md"
}

test_evaluator_skillmd_exists() {
  assert_file_exists "evaluator SKILL.md exists in skills/evaluator/" \
    "$EVALUATOR_DIR/SKILL.md"
}

test_iteration_schema_exists() {
  assert_file_exists "iteration.schema.json exists in schemas/" \
    "$SCHEMAS_DIR/iteration.schema.json"
}

# ─── SKILL.md classification table covers Improve ───

test_skillmd_improve_in_classification_table() {
  assert_file_contains "SKILL.md mentions Improve in request classification table" \
    "$SKILLS_DIR/SKILL.md" '| **Improve**'
}

test_skillmd_improve_mode_section() {
  assert_file_contains "SKILL.md has Improve Mode section" \
    "$SKILLS_DIR/SKILL.md" '### Improve Mode'
}

test_skillmd_improve_trigger_signals() {
  assert_file_contains "SKILL.md lists Improve trigger signals (iterate/refine)" \
    "$SKILLS_DIR/SKILL.md" '"iterate", "refine"'
}

# ─── improve.md contains required structural content ───

test_improve_has_sendmessage() {
  assert_file_contains "improve.md uses SendMessage for agent continuation" \
    "$PHASES_DIR/improve.md" "SendMessage"
}

test_improve_has_time_termination() {
  assert_file_contains "improve.md has TIME termination condition" \
    "$PHASES_DIR/improve.md" "TIME"
}

test_improve_has_threshold_termination() {
  assert_file_contains "improve.md has THRESHOLD termination condition" \
    "$PHASES_DIR/improve.md" "THRESHOLD"
}

test_improve_has_max_iterations_termination() {
  assert_file_contains "improve.md has MAX_ITERATIONS termination condition" \
    "$PHASES_DIR/improve.md" "MAX_ITERATIONS"
}

test_improve_has_max_evaluations_termination() {
  assert_file_contains "improve.md has MAX_EVALUATIONS termination condition" \
    "$PHASES_DIR/improve.md" "MAX_EVALUATIONS"
}

# ─── improve.md iteration loop structure ───

test_improve_has_score_function() {
  assert_file_contains "improve.md has score function / rubric definition" \
    "$PHASES_DIR/improve.md" "Score Function"
}

test_improve_has_target_selection() {
  assert_file_contains "improve.md has target selection step" \
    "$PHASES_DIR/improve.md" "Target Selection"
}

# ─── iteration.schema.json validity and required fields ───

test_iteration_schema_valid_json() {
  assert_json_valid "iteration.schema.json is valid JSON" \
    "$SCHEMAS_DIR/iteration.schema.json"
}

test_iteration_schema_has_iteration_number() {
  local required
  required=$(jq -r '.required | join(",")' "$SCHEMAS_DIR/iteration.schema.json" 2>/dev/null)
  assert_contains "iteration.schema.json required has iteration_number" \
    "$required" "iteration_number"
}

test_iteration_schema_has_score_percentage() {
  local required
  required=$(jq -r '.required | join(",")' "$SCHEMAS_DIR/iteration.schema.json" 2>/dev/null)
  assert_contains "iteration.schema.json required has score_percentage" \
    "$required" "score_percentage"
}

# ─── evaluator SKILL.md is read-only (disallowedTools enforced) ───

test_evaluator_is_readonly() {
  assert_file_contains "evaluator SKILL.md is READ-ONLY (disallowedTools enforced)" \
    "$EVALUATOR_DIR/SKILL.md" "READ-ONLY"
}

# ─── Run all tests ───
test_improve_md_exists
test_evaluator_skillmd_exists
test_iteration_schema_exists
test_skillmd_improve_in_classification_table
test_skillmd_improve_mode_section
test_skillmd_improve_trigger_signals
test_improve_has_sendmessage
test_improve_has_time_termination
test_improve_has_threshold_termination
test_improve_has_max_iterations_termination
test_improve_has_max_evaluations_termination
test_improve_has_score_function
test_improve_has_target_selection
test_iteration_schema_valid_json
test_iteration_schema_has_iteration_number
test_iteration_schema_has_score_percentage
test_evaluator_is_readonly

print_summary
