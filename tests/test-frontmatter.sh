#!/bin/bash
# Tests for SKILL.md frontmatter correctness across all 15 skill agents
source "$(dirname "$0")/framework.sh"

SKILLS_DIR="$PROJECT_ROOT/skills"

begin_suite "SKILL.md Frontmatter"

# Helper: check that a SKILL.md frontmatter field has the expected value
assert_frontmatter_field() {
  local desc="$1" file="$2" field="$3" expected="$4"
  ((_TOTAL++))
  local actual
  actual=$(grep "^${field}:" "$file" | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"')
  if [[ "$actual" == "$expected" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    expected '%s', got '%s' in %s\n" "$expected" "$actual" "$(basename "$(dirname "$file")")/SKILL.md"
  fi
}

# Helper: check that a SKILL.md has a frontmatter key present (any value)
assert_frontmatter_key_present() {
  local desc="$1" file="$2" key="$3"
  ((_TOTAL++))
  if grep -qE "^${key}:" "$file" 2>/dev/null || grep -qF "  - ${key}" "$file" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    key '%s' not found in %s\n" "$key" "$(basename "$(dirname "$file")")/SKILL.md"
  fi
}

# Helper: check that a SKILL.md has a disallowedTools entry
assert_disallowed_tool() {
  local desc="$1" file="$2" tool="$3"
  ((_TOTAL++))
  # Extract lines between disallowedTools: and the next top-level YAML key (non-space line)
  # Uses grep to find "  - ToolName" anywhere in the frontmatter (safe: tool names are unique)
  if grep -qF "  - $tool" "$file" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    '%s' not in disallowedTools in %s\n" "$tool" "$(basename "$(dirname "$file")")/SKILL.md"
  fi
}

# ─── All 15 SKILL.md files exist ───

test_all_skillmd_exist() {
  local count
  count=$(find "$SKILLS_DIR" -name "SKILL.md" | wc -l | tr -d ' ')
  assert_eq "15 SKILL.md files exist across all agents" "15" "$count"
}

# ─── Every SKILL.md has effort: high ───

test_all_skillmd_have_effort_high() {
  local missing=""
  while IFS= read -r f; do
    local agent
    agent=$(basename "$(dirname "$f")")
    local effort
    effort=$(grep "^effort:" "$f" | head -1 | sed 's/^effort:[[:space:]]*//')
    if [[ "$effort" != "high" ]]; then
      missing="${missing} ${agent}(${effort:-missing})"
    fi
  done < <(find "$SKILLS_DIR" -name "SKILL.md")
  if [[ -z "$missing" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all 15 SKILL.md files have effort: high\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m SKILL.md files with wrong effort:%s\n" "$missing"
  fi
}

# ─── Builder agents have maxTurns: 15 ───

test_software_engineer_maxturns() {
  assert_frontmatter_field "software-engineer has maxTurns: 15" \
    "$SKILLS_DIR/software-engineer/SKILL.md" "maxTurns" "15"
}

test_frontend_engineer_maxturns() {
  assert_frontmatter_field "frontend-engineer has maxTurns: 15" \
    "$SKILLS_DIR/frontend-engineer/SKILL.md" "maxTurns" "15"
}

# ─── Analysis agents have disallowedTools ───

test_security_engineer_has_disallowed() {
  assert_frontmatter_key_present "security-engineer has disallowedTools" \
    "$SKILLS_DIR/security-engineer/SKILL.md" "disallowedTools"
}

test_code_reviewer_has_disallowed() {
  assert_frontmatter_key_present "code-reviewer has disallowedTools" \
    "$SKILLS_DIR/code-reviewer/SKILL.md" "disallowedTools"
}

# ─── code-reviewer specifically has Bash in disallowedTools ───

test_code_reviewer_disallows_bash() {
  assert_disallowed_tool "code-reviewer disallows Bash" \
    "$SKILLS_DIR/code-reviewer/SKILL.md" "Bash"
}

test_code_reviewer_disallows_write() {
  assert_disallowed_tool "code-reviewer disallows Write" \
    "$SKILLS_DIR/code-reviewer/SKILL.md" "Write"
}

test_code_reviewer_disallows_edit() {
  assert_disallowed_tool "code-reviewer disallows Edit" \
    "$SKILLS_DIR/code-reviewer/SKILL.md" "Edit"
}

# ─── Evaluator has disallowedTools: [Write, Edit] ───

test_evaluator_disallows_write() {
  assert_disallowed_tool "evaluator disallows Write" \
    "$SKILLS_DIR/evaluator/SKILL.md" "Write"
}

test_evaluator_disallows_edit() {
  assert_disallowed_tool "evaluator disallows Edit" \
    "$SKILLS_DIR/evaluator/SKILL.md" "Edit"
}

test_evaluator_does_not_disallow_bash() {
  # evaluator needs to read files; Bash should NOT be disallowed
  # The evaluator's disallowedTools list only contains Write and Edit
  ((_TOTAL++))
  if ! grep -qF "  - Bash" "$SKILLS_DIR/evaluator/SKILL.md" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m evaluator does not disallow Bash (needs file reads)\n"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m evaluator should not disallow Bash\n"
  fi
}

# ─── security-engineer disallows Write and Edit ───

test_security_engineer_disallows_write() {
  assert_disallowed_tool "security-engineer disallows Write" \
    "$SKILLS_DIR/security-engineer/SKILL.md" "Write"
}

test_security_engineer_disallows_edit() {
  assert_disallowed_tool "security-engineer disallows Edit" \
    "$SKILLS_DIR/security-engineer/SKILL.md" "Edit"
}

# ─── production-grade orchestrator has no maxTurns (unlimited) ───

test_production_grade_no_maxturns() {
  ((_TOTAL++))
  if ! grep -q "^maxTurns:" "$SKILLS_DIR/production-grade/SKILL.md" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m production-grade orchestrator has no maxTurns limit\n"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m production-grade orchestrator should not have maxTurns\n"
  fi
}

# ─── Run all tests ───
test_all_skillmd_exist
test_all_skillmd_have_effort_high
test_software_engineer_maxturns
test_frontend_engineer_maxturns
test_security_engineer_has_disallowed
test_code_reviewer_has_disallowed
test_code_reviewer_disallows_bash
test_code_reviewer_disallows_write
test_code_reviewer_disallows_edit
test_evaluator_disallows_write
test_evaluator_disallows_edit
test_evaluator_does_not_disallow_bash
test_security_engineer_disallows_write
test_security_engineer_disallows_edit
test_production_grade_no_maxturns

print_summary
