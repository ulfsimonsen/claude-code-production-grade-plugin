#!/bin/bash
# PostToolUse(Write) hook: Validates state.json consistency after writes.
# Advisory only — injects warnings on inconsistency, never blocks writes
# to avoid data loss. Fires alongside receipt-validator.sh.
# Requires: jq

INPUT=$(cat)
SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: only fire on state.json writes
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ "$FILE_PATH" != *"state.json"* ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

WARNINGS=""

# Read current state
PHASE=$(jq -r '.current_phase // empty' "$STATE_FILE" 2>/dev/null)
LOADED=$(jq -r '.phase_file_loaded // "false"' "$STATE_FILE" 2>/dev/null)
LAST_READ=$(jq -r '.last_phase_read // empty' "$STATE_FILE" 2>/dev/null)
TASKS_ACTIVE=$(jq -r '.tasks_active // [] | length' "$STATE_FILE" 2>/dev/null)
LAST_TRANSITION=$(jq -r '.last_transition // empty' "$STATE_FILE" 2>/dev/null)

# Validation 1: phase_file_loaded=true requires last_phase_read timestamp
if [[ "$LOADED" == "true" && -z "$LAST_READ" ]]; then
  WARNINGS="${WARNINGS}STATE WARNING: phase_file_loaded=true but last_phase_read is missing. Set last_phase_read to current timestamp when marking phase as loaded. "
fi

# Validation 2: tasks_active non-empty requires valid current_phase
VALID_PHASES="DEFINE BUILD HARDEN SHIP SUSTAIN COMPLETE"
if [[ "$TASKS_ACTIVE" -gt 0 && -n "$PHASE" ]]; then
  PHASE_VALID=false
  for vp in $VALID_PHASES; do
    [[ "$PHASE" == "$vp" ]] && PHASE_VALID=true && break
  done
  if [[ "$PHASE_VALID" == "false" ]]; then
    WARNINGS="${WARNINGS}STATE WARNING: tasks_active has ${TASKS_ACTIVE} tasks but current_phase '${PHASE}' is not a valid phase. "
  fi
fi

# Validation 3: COMPLETE phase should have no active tasks
if [[ "$PHASE" == "COMPLETE" && "$TASKS_ACTIVE" -gt 0 ]]; then
  WARNINGS="${WARNINGS}STATE WARNING: current_phase=COMPLETE but tasks_active still has ${TASKS_ACTIVE} tasks. Clear tasks_active when pipeline completes. "
fi

# Validation 4: last_phase_read freshness (if present, should be within 30 min)
if [[ -n "$LAST_READ" ]]; then
  # Parse ISO-8601 timestamp — basic check only
  NOW=$(date -u +%s 2>/dev/null)
  if [[ -n "$NOW" ]]; then
    # Try to parse last_phase_read (macOS date -j or GNU date -d)
    READ_TS=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_READ" +%s 2>/dev/null || date -u -d "$LAST_READ" +%s 2>/dev/null || echo "")
    if [[ -n "$READ_TS" ]]; then
      AGE=$((NOW - READ_TS))
      if [[ "$AGE" -gt 1800 && "$LOADED" == "true" ]]; then
        WARNINGS="${WARNINGS}STATE WARNING: last_phase_read is ${AGE}s old (>30min). Phase file may need re-reading after compaction. "
      fi
    fi
  fi
fi

# Output warnings if any
if [[ -n "$WARNINGS" ]]; then
  jq -n --arg w "$WARNINGS" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $w
    }
  }'
else
  exit 0
fi
