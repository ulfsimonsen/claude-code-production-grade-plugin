#!/bin/bash
# Run tests targeted to changed plugin files
# Usage: run-targeted.sh <relative-path-from-plugin-root> [...]
# Always exits 0 (advisory — never blocks)
# Compatible with bash 3 (macOS default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"

if [[ $# -eq 0 ]]; then
  echo "TARGETED: no files specified"
  exit 0
fi

# Collect test suites (plain array, deduplicated at run time)
TEST_LIST=""

add_test() {
  local name="$1"
  # Dedup: only add if not already in list
  case " $TEST_LIST " in
    *" $name "*) ;;
    *) TEST_LIST="$TEST_LIST $name" ;;
  esac
}

for rel_path in "$@"; do
  # Direct test file — run it as-is
  if [[ "$rel_path" == tests/test-*.sh ]]; then
    add_test "$(basename "$rel_path")"
    continue
  fi

  # Convention fast-path for hooks: hooks/foo.sh → test-foo.sh
  if [[ "$rel_path" == hooks/*.sh ]]; then
    hook_name=$(basename "$rel_path" .sh)
    if [[ -f "$SCRIPT_DIR/test-${hook_name}.sh" ]]; then
      add_test "test-${hook_name}.sh"
      continue
    fi
  fi

  # Manifest pattern matching
  if [[ -f "$MANIFEST" ]]; then
    count=$(jq '.mappings | length' "$MANIFEST")
    i=0
    while [[ $i -lt $count ]]; do
      pattern=$(jq -r ".mappings[$i].pattern" "$MANIFEST")
      # Use bash glob matching (unquoted RHS for glob support)
      if [[ "$rel_path" == $pattern ]]; then
        while IFS= read -r test_name; do
          [[ -n "$test_name" ]] && add_test "$test_name"
        done < <(jq -r ".mappings[$i].tests[]" "$MANIFEST")
      fi
      i=$((i + 1))
    done
  fi
done

# Trim leading space
TEST_LIST="${TEST_LIST# }"

# If no tests matched, report and exit
if [[ -z "$TEST_LIST" ]]; then
  echo "NO_TESTS_MAPPED: $*"
  exit 0
fi

# Run matched test suites
RAN=0
PASSED=0
FAILED=0
FAILED_NAMES=""

for test_name in $TEST_LIST; do
  test_path="$SCRIPT_DIR/$test_name"
  if [[ ! -f "$test_path" ]]; then
    continue
  fi
  RAN=$((RAN + 1))
  if bash "$test_path" > /dev/null 2>&1; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    FAILED_NAMES="$FAILED_NAMES $test_name"
  fi
done

# Print machine-parseable summary
if [[ $FAILED -eq 0 ]]; then
  echo "TARGETED: ${RAN}/${RAN} passed"
else
  echo "TARGETED: ${PASSED}/${RAN} passed, ${FAILED} FAILED (${FAILED_NAMES# })"
fi

exit 0
