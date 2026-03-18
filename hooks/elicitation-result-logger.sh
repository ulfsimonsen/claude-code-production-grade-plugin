#!/bin/bash
# PostToolUse(ElicitationResult) hook: Logs user responses from Elicitation
# forms for pipeline analytics. Captures which options users choose so the
# pipeline can track engagement and surface patterns across sessions.
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

# Extract result data — ElicitationResult has tool_response with the user's choices
ACTION=$(echo "$INPUT" | jq -r '.tool_response.action // empty')
FORM_TITLE=$(echo "$INPUT" | jq -r '.tool_response.title // .tool_input.title // empty')
PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null)

# Log the result (never log actual user text — log only action type and field count)
FIELD_COUNT=$(echo "$INPUT" | jq '.tool_response.values // {} | keys | length' 2>/dev/null || echo 0)

ANALYTICS_LOG="$SUITE_DIR/.orchestrator/elicitation-log.md"
mkdir -p "$SUITE_DIR/.orchestrator"
cat >> "$ANALYTICS_LOG" <<EOF

## ElicitationResult — ${TIMESTAMP}
- **Phase:** ${PHASE}
- **Form:** ${FORM_TITLE:-untitled}
- **Action:** ${ACTION:-unknown}
- **Fields responded:** ${FIELD_COUNT}
EOF

CONTEXT="Elicitation result logged: action=${ACTION:-unknown}, phase=${PHASE}, ${FIELD_COUNT} fields responded."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
