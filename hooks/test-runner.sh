#!/bin/bash
# PostToolUse(Write|Edit) hook: Runs targeted tests when plugin source files change.
# Returns advisory context — never blocks (always exits 0).
# Requires: jq

INPUT=$(cat)

_R="${CLAUDE_PLUGIN_ROOT}"
[ -z "$_R" ] && exit 0

# FAST PATH: if stdin doesn't contain plugin root path at all, skip jq entirely
# bash string matching is <1ms vs jq's ~50ms
[[ "$INPUT" != *"$_R/"* ]] && exit 0

# Only parse JSON for potential plugin files
command -v jq >/dev/null 2>&1 || exit 0
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" || "$FILE_PATH" != "$_R/"* ]] && exit 0

# Compute relative path from plugin root
REL_PATH="${FILE_PATH#$_R/}"

# Run targeted tests
RESULT=$(bash "$_R/tests/run-targeted.sh" "$REL_PATH" 2>&1)

# Format advisory context
if [[ "$RESULT" == NO_TESTS_MAPPED* ]]; then
  CONTEXT="AUTO-TEST: no tests mapped for ${REL_PATH}"
elif [[ "$RESULT" == *"FAILED"* ]]; then
  CONTEXT="AUTO-TEST: ${RESULT} for ${REL_PATH} — run 'bash tests/run-all.sh' for full output"
else
  CONTEXT="AUTO-TEST: ${RESULT} for ${REL_PATH}"
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "$CONTEXT"
  }
}
EOF

exit 0
