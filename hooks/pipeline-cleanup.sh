#!/bin/bash
# Stop hook: Fires when the Claude Code session ends. If a pipeline is active,
# writes a partial-completion marker, logs the stop event, and writes a
# cleanup-pending marker with instructions so the next session can detect
# the interrupted state and execute critical cleanup steps.
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

# --- Layer 4: Active cleanup enforcement ---
# Write cleanup-pending marker with instructions for critical steps that
# must execute on next session start. This catches the case where sustain.md
# was never read and TeamDelete/CLAUDE.md write were skipped.
CLEANUP_PENDING_FILE="$SUITE_DIR/.orchestrator/cleanup-pending"

# Determine what cleanup is needed based on what's missing
CLEANUP_STEPS=""

# Check if Production-Grade Native directive was written to CLAUDE.md
if [[ -f "CLAUDE.md" ]]; then
  if ! grep -q "Production Grade Native" "CLAUDE.md" 2>/dev/null; then
    CLEANUP_STEPS="${CLEANUP_STEPS}write-claude-md,"
  fi
else
  CLEANUP_STEPS="${CLEANUP_STEPS}write-claude-md,"
fi

# TeamDelete is always needed if pipeline didn't complete
CLEANUP_STEPS="${CLEANUP_STEPS}team-delete,"

# CLAUDE_PLUGIN_DATA persistence
CLEANUP_STEPS="${CLEANUP_STEPS}persist-plugin-data,"

cat > "$CLEANUP_PENDING_FILE" <<EOF
# Cleanup Pending — ${TIMESTAMP}
phase: ${PHASE}
wave: ${WAVE}
tasks_completed: ${TASKS_DONE}
steps: ${CLEANUP_STEPS}
---
Pipeline was interrupted at ${PHASE}/${WAVE} with ${TASKS_DONE} tasks completed.
The following cleanup steps must execute on next session:
1. Run TeamDelete(team_name="production-grade") to free orphaned agents
2. Write Production-Grade Native directive to CLAUDE.md if missing
3. Write pipeline analytics to CLAUDE_PLUGIN_DATA if available
EOF

CONTEXT="Pipeline stop recorded: phase=${PHASE}, wave=${WAVE}, ${TASKS_DONE} tasks completed. Partial marker written. Cleanup-pending marker written with ${CLEANUP_STEPS%,} steps. Resume on next session."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: $ctx
  }
}'
