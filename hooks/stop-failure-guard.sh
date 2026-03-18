#!/bin/bash
# StopFailure hook: Logs API errors (rate limit, auth failure) to the error
# log and outputs retry guidance so the orchestrator knows to pause and retry
# rather than silently failing.
# Requires: jq

INPUT=$(cat)
_R="${CLAUDE_PLUGIN_ROOT}"; [ -z "$_R" ] && exit 0

SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

ERROR_TYPE=$(echo "$INPUT" | jq -r '.error_type // empty')
ERROR_MSG=$(echo "$INPUT" | jq -r '.error_message // .message // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null)
WAVE=$(jq -r '.current_wave // "unknown"' "$STATE_FILE" 2>/dev/null)

# Append to error log
ERROR_LOG="$SUITE_DIR/.orchestrator/error-log.md"
mkdir -p "$SUITE_DIR/.orchestrator"
cat >> "$ERROR_LOG" <<EOF

## StopFailure — ${TIMESTAMP}
- **Phase:** ${PHASE}, Wave: ${WAVE}
- **Error type:** ${ERROR_TYPE:-unknown}
- **Message:** ${ERROR_MSG:-no message}
EOF

# Determine retry guidance based on error type
case "$ERROR_TYPE" in
  rate_limit|RateLimitError)
    GUIDANCE="Rate limit hit — pause 60 seconds then retry the current task." ;;
  auth|AuthenticationError|permission_error)
    GUIDANCE="Authentication failure — check API key and permissions before retrying." ;;
  *)
    GUIDANCE="API failure (${ERROR_TYPE:-unknown}) — log reviewed. Retry the current task or escalate if persistent." ;;
esac

jq -n --arg ctx "$GUIDANCE" '{
  hookSpecificOutput: {
    hookEventName: "StopFailure",
    additionalContext: $ctx
  }
}'
