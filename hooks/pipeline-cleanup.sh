#!/bin/bash
# Stop hook: Fires when the Claude Code session ends. If a pipeline is active,
# writes a partial-completion marker and logs the stop event so the next
# session can detect the interrupted state and offer to resume.
# Requires: jq

INPUT=$(cat)
_R="${CLAUDE_PLUGIN_ROOT}"; [ -z "$_R" ] && exit 0

SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null)
WAVE=$(jq -r '.current_wave // "unknown"' "$STATE_FILE" 2>/dev/null)
TASKS_DONE=$(jq -r '.tasks_completed // [] | length' "$STATE_FILE" 2>/dev/null || echo 0)

# Check if pipeline already marked complete — no cleanup needed
PIPELINE_STATUS_FILE="$SUITE_DIR/.orchestrator/pipeline-status"
if [[ -f "$PIPELINE_STATUS_FILE" ]]; then
  STATUS=$(cat "$PIPELINE_STATUS_FILE" 2>/dev/null)
  if [[ "$STATUS" == "complete" || "$STATUS" == "rejected" ]]; then
    exit 0
  fi
fi

# Write partial-completion marker (only if pipeline is in progress)
echo "partial" > "$PIPELINE_STATUS_FILE"

# Log the stop event
STOP_LOG="$SUITE_DIR/.orchestrator/error-log.md"
mkdir -p "$SUITE_DIR/.orchestrator"
cat >> "$STOP_LOG" <<EOF

## SessionStop — ${TIMESTAMP}
- **Phase:** ${PHASE}, Wave: ${WAVE}
- **Tasks completed:** ${TASKS_DONE}
- **Status:** partial (session ended mid-pipeline)
- **Resume:** On next session start, pipeline state will be re-detected and re-orientation offered.
EOF

CONTEXT="Pipeline stop recorded: phase=${PHASE}, wave=${WAVE}, ${TASKS_DONE} tasks completed. Partial marker written. Resume on next session."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: $ctx
  }
}'
