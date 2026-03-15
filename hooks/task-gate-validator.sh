#!/bin/bash
# TaskCompleted hook: Prevents task completion if receipt is invalid or
# artifacts are missing. Exit code 2 blocks completion.
# Requires: jq

INPUT=$(cat)

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')

# Guard: only validate production-grade tasks
[[ "$TEAM_NAME" != "production-grade" ]] && exit 0

SUITE_DIR="Claude-Production-Grade-Suite"
RECEIPTS_DIR="$SUITE_DIR/.orchestrator/receipts"

# Extract task ID from subject (e.g., "T3a: Software Engineer" → T3a)
TASK_ID=$(echo "$TASK_SUBJECT" | grep -oE '^T[0-9]+[a-z]?')
[[ -z "$TASK_ID" ]] && exit 0

# Check receipt exists
RECEIPT=$(find "$RECEIPTS_DIR" -name "${TASK_ID}-*.json" 2>/dev/null | head -1)
if [[ -z "$RECEIPT" || ! -f "$RECEIPT" ]]; then
  echo "Task $TASK_ID cannot complete: no receipt found at $RECEIPTS_DIR/${TASK_ID}-*.json. Write a valid receipt before marking complete." >&2
  exit 2
fi

# Validate receipt has required fields
MISSING=""
for field in task_id skill status completed_at artifacts metrics effort; do
  if ! jq -e ".$field" "$RECEIPT" >/dev/null 2>&1; then
    MISSING="${MISSING} ${field}"
  fi
done

if [[ -n "$MISSING" ]]; then
  echo "Task $TASK_ID receipt invalid: missing required fields:${MISSING}. Fix receipt at $RECEIPT." >&2
  exit 2
fi

# Validate effort sub-fields
for sub in files_read files_written tool_calls; do
  if ! jq -e ".effort.$sub" "$RECEIPT" >/dev/null 2>&1; then
    echo "Task $TASK_ID receipt invalid: missing effort.$sub. Fix receipt at $RECEIPT." >&2
    exit 2
  fi
done

# Validate all artifacts exist on disk
ARTIFACT_MISSING=""
while IFS= read -r artifact; do
  [[ -z "$artifact" ]] && continue
  [[ ! -f "$artifact" && ! -d "$artifact" ]] && ARTIFACT_MISSING="${ARTIFACT_MISSING} ${artifact}"
done < <(jq -r '.artifacts[]? // empty' "$RECEIPT" 2>/dev/null)

if [[ -n "$ARTIFACT_MISSING" ]]; then
  echo "Task $TASK_ID receipt lists artifacts that don't exist:${ARTIFACT_MISSING}. Create the files or fix the receipt at $RECEIPT." >&2
  exit 2
fi

exit 0
