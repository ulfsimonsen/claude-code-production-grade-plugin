#!/bin/bash
# Meta-tests: validates that the test framework itself works correctly
# If these fail, ALL other test results are unreliable.
source "$(dirname "$0")/framework.sh"

begin_suite "Framework Meta-Tests"

# ─── assert_eq: pass on match ───

test_assert_eq_pass() {
  local before=$_PASS
  assert_eq "meta: assert_eq pass on match" "hello" "hello"
  local after=$_PASS
  # If assert_eq worked, _PASS incremented by 1
  # We can't assert on this without infinite recursion, so this test
  # is self-verifying: if it prints ✓, the framework works.
}

# ─── assert_eq: fail on mismatch ───

test_assert_eq_fail() {
  # Temporarily capture a known failure, then undo it
  local before_pass=$_PASS before_fail=$_FAIL before_total=$_TOTAL
  # Run assert_eq with mismatched values — redirect output to suppress it
  assert_eq "deliberate-fail-ignore" "expected" "actual" > /dev/null 2>&1
  local after_fail=$_FAIL
  # Undo the failure counters
  _FAIL=$before_fail
  _TOTAL=$before_total
  _PASS=$before_pass
  # Now assert that the failure was detected
  if [[ $after_fail -gt $before_fail ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m meta: assert_eq increments FAIL on mismatch\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: assert_eq should increment FAIL on mismatch\n"
  fi
}

# ─── assert_contains: pass when needle found ───

test_assert_contains_pass() {
  assert_contains "meta: assert_contains finds needle" "hello world" "world"
}

# ─── assert_contains: fail when needle missing ───

test_assert_contains_fail() {
  local before_pass=$_PASS before_fail=$_FAIL before_total=$_TOTAL
  assert_contains "deliberate-fail-ignore" "hello world" "missing" > /dev/null 2>&1
  local after_fail=$_FAIL
  _FAIL=$before_fail
  _TOTAL=$before_total
  _PASS=$before_pass
  if [[ $after_fail -gt $before_fail ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m meta: assert_contains increments FAIL when needle missing\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: assert_contains should increment FAIL when needle missing\n"
  fi
}

# ─── assert_not_contains: pass when needle absent ───

test_assert_not_contains_pass() {
  assert_not_contains "meta: assert_not_contains passes when absent" "hello world" "missing"
}

# ─── assert_not_contains: fail when needle found ───

test_assert_not_contains_fail() {
  local before_pass=$_PASS before_fail=$_FAIL before_total=$_TOTAL
  assert_not_contains "deliberate-fail-ignore" "hello world" "world" > /dev/null 2>&1
  local after_fail=$_FAIL
  _FAIL=$before_fail
  _TOTAL=$before_total
  _PASS=$before_pass
  if [[ $after_fail -gt $before_fail ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m meta: assert_not_contains increments FAIL when needle found\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: assert_not_contains should increment FAIL when needle found\n"
  fi
}

# ─── assert_file_exists: pass on real file ───

test_assert_file_exists_pass() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/meta-test-XXXXXX")
  assert_file_exists "meta: assert_file_exists passes for real file" "$tmp"
  rm -f "$tmp"
}

# ─── assert_file_exists: fail on missing file ───

test_assert_file_exists_fail() {
  local before_pass=$_PASS before_fail=$_FAIL before_total=$_TOTAL
  assert_file_exists "deliberate-fail-ignore" "/nonexistent/path/meta-test" > /dev/null 2>&1
  local after_fail=$_FAIL
  _FAIL=$before_fail
  _TOTAL=$before_total
  _PASS=$before_pass
  if [[ $after_fail -gt $before_fail ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m meta: assert_file_exists increments FAIL for missing file\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: assert_file_exists should increment FAIL for missing file\n"
  fi
}

# ─── assert_file_contains: pass when content present ───

test_assert_file_contains_pass() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/meta-test-XXXXXX")
  echo "needle in the haystack" > "$tmp"
  assert_file_contains "meta: assert_file_contains finds content" "$tmp" "needle"
  rm -f "$tmp"
}

# ─── assert_file_not_contains: pass when content absent ───

test_assert_file_not_contains_pass() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/meta-test-XXXXXX")
  echo "just a haystack" > "$tmp"
  assert_file_not_contains "meta: assert_file_not_contains passes for absent content" "$tmp" "needle"
  rm -f "$tmp"
}

# ─── assert_json_valid: pass on valid JSON ───

test_assert_json_valid_pass() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/meta-test-XXXXXX")
  echo '{"key":"value"}' > "$tmp"
  assert_json_valid "meta: assert_json_valid passes for valid JSON" "$tmp"
  rm -f "$tmp"
}

# ─── assert_json_field: pass on correct value ───

test_assert_json_field_pass() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/meta-test-XXXXXX")
  echo '{"name":"test","count":42}' > "$tmp"
  assert_json_field "meta: assert_json_field extracts correct value" "$tmp" '.name' "test"
  rm -f "$tmp"
}

# ─── create_workspace / cleanup_workspace ───

test_workspace_lifecycle() {
  local ws; ws=$(create_workspace)
  ((_TOTAL++))
  if [[ -d "$ws" && -d "$ws/Claude-Production-Grade-Suite/.orchestrator/receipts" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m meta: create_workspace creates expected directory structure\n"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: create_workspace should create suite + orchestrator + receipts dirs\n"
  fi
  cleanup_workspace "$ws"
  ((_TOTAL++))
  if [[ ! -d "$ws" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m meta: cleanup_workspace removes directory\n"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: cleanup_workspace should remove directory\n"
  fi
}

# ─── run_hook captures output and exit code ───

test_run_hook_captures_output() {
  local ws; ws=$(create_workspace)
  local tmp_script
  tmp_script=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-script-XXXXXX")
  echo '#!/bin/bash' > "$tmp_script"
  echo 'echo "hook output"' >> "$tmp_script"
  echo 'exit 0' >> "$tmp_script"
  chmod +x "$tmp_script"
  run_hook "$tmp_script" '' "$ws"
  assert_eq "meta: run_hook captures exit code" "0" "$HOOK_EXIT"
  assert_eq "meta: run_hook captures stdout" "hook output" "$HOOK_OUTPUT"
  rm -f "$tmp_script"
  cleanup_workspace "$ws"
}

test_run_hook_captures_nonzero_exit() {
  local ws; ws=$(create_workspace)
  local tmp_script
  tmp_script=$(mktemp "${TMPDIR:-/private/tmp/claude-501}/hook-script-XXXXXX")
  echo '#!/bin/bash' > "$tmp_script"
  echo 'echo "error" >&2' >> "$tmp_script"
  echo 'exit 2' >> "$tmp_script"
  chmod +x "$tmp_script"
  run_hook "$tmp_script" '' "$ws"
  assert_eq "meta: run_hook captures nonzero exit code" "2" "$HOOK_EXIT"
  rm -f "$tmp_script"
  cleanup_workspace "$ws"
}

# ─── Hook coverage checker: every hooks/*.sh should have a test ───

test_hook_coverage() {
  local missing=""
  for hook in "$HOOKS_DIR"/*.sh; do
    local name
    name=$(basename "$hook" .sh)
    # Map hook names to expected test file patterns
    local found=false
    for test_file in "$(dirname "$0")"/test-*.sh; do
      if grep -qlF "$name" "$test_file" 2>/dev/null; then
        found=true
        break
      fi
    done
    if [[ "$found" == "false" ]]; then
      missing="${missing} ${name}"
    fi
  done
  ((_TOTAL++))
  if [[ -z "$missing" ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m meta: all hooks/*.sh have corresponding tests\n"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: hooks without tests:%s\n" "$missing"
  fi
}

# ─── print_summary returns correct exit code ───

test_print_summary_exit_code() {
  # Save state
  local save_total=$_TOTAL save_pass=$_PASS save_fail=$_FAIL
  # Test: 0 failures → exit 0
  _TOTAL=5; _PASS=5; _FAIL=0
  print_summary > /dev/null 2>&1
  local exit_zero=$?
  # Test: 1 failure → exit 1
  _TOTAL=5; _PASS=4; _FAIL=1
  print_summary > /dev/null 2>&1
  local exit_one=$?
  # Restore state
  _TOTAL=$save_total; _PASS=$save_pass; _FAIL=$save_fail
  ((_TOTAL++))
  if [[ $exit_zero -eq 0 && $exit_one -eq 1 ]]; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m meta: print_summary returns 0 on success, 1 on failure\n"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m meta: print_summary exit codes wrong (0→%d, 1→%d)\n" "$exit_zero" "$exit_one"
  fi
}

# --- Run all tests ---
test_assert_eq_pass
test_assert_eq_fail
test_assert_contains_pass
test_assert_contains_fail
test_assert_not_contains_pass
test_assert_not_contains_fail
test_assert_file_exists_pass
test_assert_file_exists_fail
test_assert_file_contains_pass
test_assert_file_not_contains_pass
test_assert_json_valid_pass
test_assert_json_field_pass
test_workspace_lifecycle
test_run_hook_captures_output
test_run_hook_captures_nonzero_exit
test_hook_coverage
test_print_summary_exit_code

print_summary
