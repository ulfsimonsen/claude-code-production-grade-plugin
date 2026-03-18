#!/bin/bash
# PostToolUse(Write) hook: Validates receipt JSON against schema after every
# write to the receipts directory. Returns additionalContext with specific
# missing fields if validation fails.
# Requires: jq

INPUT=$(cat)

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Guard: only validate receipt files
[[ "$FILE_PATH" != *"/receipts/"*.json ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Extract task ID from filename (e.g., T1-product-manager.json → T1)
BASENAME=$(basename "$FILE_PATH" .json)
TASK_ID=$(echo "$BASENAME" | grep -oE '^T[0-9]+[a-z]?')
[[ -z "$TASK_ID" ]] && exit 0

# Determine schema directory — check CLAUDE_PLUGIN_ROOT first, fall back to relative
if [[ -n "$CLAUDE_PLUGIN_ROOT" ]]; then
  SCHEMA_DIR="$CLAUDE_PLUGIN_ROOT/skills/production-grade/schemas"
else
  # Try to find schemas relative to this script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCHEMA_DIR="$SCRIPT_DIR/../skills/production-grade/schemas"
fi

TASK_SCHEMA="$SCHEMA_DIR/receipt-${TASK_ID}.schema.json"
ERRORS=""

# Validate base required fields
for field in task_id skill status completed_at artifacts metrics effort; do
  if ! jq -e ".$field" "$FILE_PATH" >/dev/null 2>&1; then
    ERRORS="${ERRORS} missing:${field}"
  fi
done

# Validate effort sub-fields
if jq -e ".effort" "$FILE_PATH" >/dev/null 2>&1; then
  for sub in files_read files_written tool_calls; do
    if ! jq -e ".effort.$sub" "$FILE_PATH" >/dev/null 2>&1; then
      ERRORS="${ERRORS} missing:effort.${sub}"
    fi
  done
fi

# Validate status enum
STATUS=$(jq -r '.status // empty' "$FILE_PATH")
case "$STATUS" in
  completed|failed|skipped) ;;
  *) [[ -n "$STATUS" ]] && ERRORS="${ERRORS} invalid_status:${STATUS}" ;;
esac

# Validate artifacts exist on disk
while IFS= read -r artifact; do
  [[ -z "$artifact" ]] && continue
  if [[ ! -f "$artifact" && ! -d "$artifact" ]]; then
    ERRORS="${ERRORS} artifact_missing:${artifact}"
  fi
done < <(jq -r '.artifacts[]? // empty' "$FILE_PATH" 2>/dev/null)

# Validate task-specific required metrics if schema exists
if [[ -f "$TASK_SCHEMA" ]]; then
  while IFS= read -r metric; do
    [[ -z "$metric" ]] && continue
    if ! jq -e ".metrics.$metric" "$FILE_PATH" >/dev/null 2>&1; then
      ERRORS="${ERRORS} missing_metric:${metric}"
    fi
  done < <(jq -r '.required_metrics[]? // empty' "$TASK_SCHEMA" 2>/dev/null)

  # Validate min_values if specified
  while IFS='=' read -r key val; do
    [[ -z "$key" ]] && continue
    ACTUAL=$(jq -r ".metrics.$key // 0" "$FILE_PATH" 2>/dev/null)
    if [[ "$ACTUAL" -lt "$val" ]] 2>/dev/null; then
      ERRORS="${ERRORS} below_min:${key}=${ACTUAL}<${val}"
    fi
  done < <(jq -r '.min_values // {} | to_entries[] | "\(.key)=\(.value)"' "$TASK_SCHEMA" 2>/dev/null)
fi

if [[ -n "$ERRORS" ]]; then
  jq -n --arg errs "$ERRORS" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("RECEIPT VALIDATION FAILED:" + $errs + ". Fix the receipt before proceeding.")
    }
  }'
else
  # Update state.json to mark task as completed (flock prevents race conditions)
  STATE_FILE="Claude-Production-Grade-Suite/.orchestrator/state.json"
  if [[ -f "$STATE_FILE" ]]; then
    (
      flock -x 200
      # Add task to completed list if not already there
      ALREADY=$(jq -r --arg tid "$TASK_ID" '.tasks_completed // [] | index($tid) // empty' "$STATE_FILE" 2>/dev/null)
      if [[ -z "$ALREADY" ]]; then
        jq --arg tid "$TASK_ID" '.tasks_completed = ((.tasks_completed // []) + [$tid] | unique)' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
      fi
    ) 200>"${STATE_FILE}.lock"
  fi
  exit 0
fi
