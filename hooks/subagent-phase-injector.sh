#!/bin/bash
# SubagentStart hook: Injects phase-specific context into pipeline subagents.
# Primary JIT mechanism — structurally injects phase instructions into every
# pipeline agent instead of relying on the orchestrator to include them.
# Also injects critical directives (Layer 3 enforcement) so mandatory steps
# reach every subagent regardless of whether the orchestrator read the phase file.
# Requires: jq
#
# v7.0.0: Added agent_id and agent_type extraction for per-agent tracking.
# Added worktree field awareness for branch-isolated parallel execution.
# v7.1.0: Added critical directive injection from phases/critical/*.txt.

INPUT=$(cat)
SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

# Extract agent identity fields (v7.0.0)
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
WORKTREE=$(echo "$INPUT" | jq -r '.worktree // empty')

PHASE=$(jq -r '.current_phase // empty' "$STATE_FILE")
WAVE=$(jq -r '.current_wave // empty' "$STATE_FILE")
[[ -z "$PHASE" ]] && exit 0

# Build context injection — include agent_id for per-agent tracking
CONTEXT="[Production-Grade Pipeline] Phase: ${PHASE}, Wave: ${WAVE}."
[[ -n "$AGENT_ID" ]] && CONTEXT="$CONTEXT Agent: ${AGENT_ID}${AGENT_TYPE:+ (${AGENT_TYPE})}."
[[ -n "$WORKTREE" ]] && CONTEXT="$CONTEXT Worktree: ${WORKTREE}."

# Include phase-specific re-anchoring pointers
case "$WAVE" in
  A) CONTEXT="$CONTEXT Read BRD at $SUITE_DIR/product-manager/BRD/brd.md and architecture at docs/architecture/." ;;
  B) CONTEXT="$CONTEXT Read Wave A analysis outputs: $SUITE_DIR/qa-engineer/test-plan.md, $SUITE_DIR/security-engineer/threat-model/, $SUITE_DIR/code-reviewer/checklist.md." ;;
  C) CONTEXT="$CONTEXT Read Wave B findings: $SUITE_DIR/security-engineer/code-audit/, $SUITE_DIR/code-reviewer/, $SUITE_DIR/qa-engineer/." ;;
  D) CONTEXT="$CONTEXT Read Wave C outputs: $SUITE_DIR/sre/, docs/runbooks/." ;;
esac

# Add settings context
SETTINGS_FILE="$SUITE_DIR/.orchestrator/settings.md"
if [[ -f "$SETTINGS_FILE" ]]; then
  ENGAGEMENT=$(grep -o 'Engagement: [a-zA-Z]*' "$SETTINGS_FILE" | cut -d' ' -f2)
  [[ -n "$ENGAGEMENT" ]] && CONTEXT="$CONTEXT Engagement: ${ENGAGEMENT}."
fi

# --- Layer 3: Inject critical directives ---
# Every subagent gets the mandatory steps for their phase regardless of
# whether the orchestrator read the phase file.
PHASE_LOWER=$(echo "$PHASE" | tr '[:upper:]' '[:lower:]')
CRITICAL_FILE=""
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  CRITICAL_FILE="${CLAUDE_PLUGIN_ROOT}/skills/production-grade/phases/critical/${PHASE_LOWER}-critical.txt"
fi

if [[ -n "$CRITICAL_FILE" && -f "$CRITICAL_FILE" ]]; then
  CRITICAL_CONTENT=$(cat "$CRITICAL_FILE" 2>/dev/null)
  if [[ -n "$CRITICAL_CONTENT" ]]; then
    CONTEXT="$CONTEXT [CRITICAL DIRECTIVES] ${CRITICAL_CONTENT}"
  fi
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SubagentStart",
    additionalContext: $ctx
  }
}'
