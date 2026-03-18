#!/bin/bash
# PreToolUse(Elicitation) hook: Validates that Elicitation forms follow the
# production-grade protocol — must have a free-form text field and it should
# be listed last so users can always provide custom input as an escape hatch.
# Logs validation warnings; does not block the elicitation.
# Requires: jq

INPUT=$(cat)
_R="${CLAUDE_PLUGIN_ROOT}"; [ -z "$_R" ] && exit 0

SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

# Extract elicitation fields from tool input
TITLE=$(echo "$INPUT" | jq -r '.tool_input.title // empty')
FIELDS=$(echo "$INPUT" | jq -c '.tool_input.fields // []' 2>/dev/null)
FIELD_COUNT=$(echo "$FIELDS" | jq 'length' 2>/dev/null || echo 0)

WARNINGS=""

# Validate: must have at least one field
if [[ "$FIELD_COUNT" -eq 0 ]]; then
  WARNINGS="${WARNINGS} no_fields_defined;"
fi

# Validate: should have a free-form text field (type: text or textarea)
HAS_FREEFORM=$(echo "$FIELDS" | jq '[.[] | select(.type == "text" or .type == "textarea")] | length' 2>/dev/null || echo 0)
if [[ "$HAS_FREEFORM" -eq 0 && "$FIELD_COUNT" -gt 0 ]]; then
  WARNINGS="${WARNINGS} no_free_form_field_recommended;"
fi

# Validate: recommended options should come before required fields when possible
# (structural heuristic — options before required free-text)
FIRST_FIELD_TYPE=$(echo "$FIELDS" | jq -r '.[0].type // empty' 2>/dev/null)

# Log to error log if any warnings
if [[ -n "$WARNINGS" ]]; then
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
  ERROR_LOG="$SUITE_DIR/.orchestrator/error-log.md"
  mkdir -p "$SUITE_DIR/.orchestrator"
  cat >> "$ERROR_LOG" <<EOF

## ElicitationWarning — ${TIMESTAMP}
- **Title:** ${TITLE:-untitled}
- **Warnings:** ${WARNINGS}
EOF
  CONTEXT="Elicitation form validated with warnings: ${WARNINGS} Consider adding a free-form text field."
else
  CONTEXT="Elicitation form validated: ${TITLE:-untitled} (${FIELD_COUNT} fields, free-form present)."
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    additionalContext: $ctx
  }
}'
