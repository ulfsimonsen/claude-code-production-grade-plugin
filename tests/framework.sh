#!/bin/bash
# Lightweight bash test framework for production-grade plugin hooks & schemas
# Usage: source this file, call assert_*, call print_summary at end

_PASS=0
_FAIL=0
_TOTAL=0

# Resolve project root (one level up from tests/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HOOKS_DIR="$PROJECT_ROOT/hooks"
SCHEMAS_DIR="$PROJECT_ROOT/skills/production-grade/schemas"

begin_suite() {
  printf "\n━━━ %s ━━━\n" "$1"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  ((_TOTAL++))
  if [[ "$expected" == "$actual" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    expected: '%s'\n    actual:   '%s'\n" "$expected" "$actual"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  ((_TOTAL++))
  if [[ "$haystack" == *"$needle"* ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    output does not contain: '%s'\n" "$needle"
    printf "    full output: '%s'\n" "$haystack"
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  ((_TOTAL++))
  if [[ "$haystack" != *"$needle"* ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    output should not contain: '%s'\n" "$needle"
  fi
}

assert_file_exists() {
  local desc="$1" file="$2"
  ((_TOTAL++))
  if [[ -f "$file" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    file not found: '%s'\n" "$file"
  fi
}

assert_json_valid() {
  local desc="$1" file="$2"
  ((_TOTAL++))
  if jq empty "$file" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    invalid JSON: '%s'\n" "$file"
  fi
}

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

assert_json_field() {
  local desc="$1" file="$2" field="$3" expected="$4"
  ((_TOTAL++))
  local actual
  actual=$(jq -r "$field" "$file" 2>/dev/null)
  if [[ "$actual" == "$expected" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    field %s: expected '%s', got '%s'\n" "$field" "$expected" "$actual"
  fi
}

# Create a temp workspace mimicking a project root with Claude-Production-Grade-Suite/
create_workspace() {
  local ws
  ws=$(mktemp -d "${TMPDIR:-/private/tmp/claude-501}/pg-test-XXXXXX")
  mkdir -p "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts"
  echo "$ws"
}

cleanup_workspace() {
  [[ -n "$1" && -d "$1" && "$1" == *pg-test-* ]] && rm -rf "$1"
}

# Run a hook script with piped input, capture stdout and exit code
# Usage: run_hook <script> <input_json> [working_dir]
# Sets: HOOK_OUTPUT, HOOK_EXIT, HOOK_STDERR
run_hook() {
  local script="$1" input="$2" workdir="${3:-.}"
  HOOK_STDERR=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-stderr-XXXXXX")
  HOOK_OUTPUT=$(cd "$workdir" && echo "$input" | bash "$script" 2>"$HOOK_STDERR")
  HOOK_EXIT=$?
  HOOK_STDERR_CONTENT=$(cat "$HOOK_STDERR")
  rm -f "$HOOK_STDERR"
}

print_summary() {
  printf "\n  Total: %d  Passed: \033[32m%d\033[0m  Failed: \033[31m%d\033[0m\n" "$_TOTAL" "$_PASS" "$_FAIL"
  [[ $_FAIL -eq 0 ]] && return 0 || return 1
}
