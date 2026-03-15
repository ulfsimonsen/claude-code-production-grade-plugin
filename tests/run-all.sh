#!/bin/bash
# Run all test suites for production-grade plugin
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
FAILED_NAMES=()

printf "\n╔══════════════════════════════════════════════════════════╗\n"
printf "║  Production-Grade Plugin — Test Suite                    ║\n"
printf "║  Commit: 6158f16 (hooks + schemas + hooks.json)         ║\n"
printf "╚══════════════════════════════════════════════════════════╝\n"

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  ((TOTAL_SUITES++))
  bash "$test_file"
  if [[ $? -eq 0 ]]; then
    ((PASSED_SUITES++))
  else
    ((FAILED_SUITES++))
    FAILED_NAMES+=("$(basename "$test_file")")
  fi
done

printf "\n╔══════════════════════════════════════════════════════════╗\n"
printf "║  OVERALL RESULTS                                         ║\n"
printf "╠══════════════════════════════════════════════════════════╣\n"
printf "║  Suites: %d total, \033[32m%d passed\033[0m, \033[31m%d failed\033[0m               ║\n" "$TOTAL_SUITES" "$PASSED_SUITES" "$FAILED_SUITES"

if [[ ${#FAILED_NAMES[@]} -gt 0 ]]; then
  printf "║                                                          ║\n"
  printf "║  Failed:                                                 ║\n"
  for name in "${FAILED_NAMES[@]}"; do
    printf "║    - %-50s ║\n" "$name"
  done
fi

printf "╚══════════════════════════════════════════════════════════╝\n"

[[ $FAILED_SUITES -eq 0 ]] && exit 0 || exit 1
