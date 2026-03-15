#!/bin/bash
# SubagentStart hook: Injects phase-specific context into pipeline subagents.
# Primary JIT mechanism — structurally injects phase instructions into every
# pipeline agent instead of relying on the orchestrator to include them.
# Requires: jq

INPUT=$(cat)
SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

PHASE=$(jq -r '.current_phase // empty' "$STATE_FILE")
WAVE=$(jq -r '.current_wave // empty' "$STATE_FILE")
[[ -z "$PHASE" ]] && exit 0

# Build context injection
CONTEXT="[Production-Grade Pipeline] Phase: ${PHASE}, Wave: ${WAVE}."

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
  ENGAGEMENT=$(grep -o 'Engagement: [a-z]*' "$SETTINGS_FILE" | cut -d' ' -f2)
  [[ -n "$ENGAGEMENT" ]] && CONTEXT="$CONTEXT Engagement: ${ENGAGEMENT}."
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SubagentStart",
    additionalContext: $ctx
  }
}'
