#!/bin/bash
# PreToolUse(Agent) hook: Reminds orchestrator to read phase file before
# dispatching agents. Backup mechanism — SubagentStart is primary.
# Requires: jq

INPUT=$(cat)
SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

PHASE=$(jq -r '.current_phase // empty' "$STATE_FILE")
LOADED=$(jq -r '.phase_file_loaded // false' "$STATE_FILE")

if [[ "$LOADED" != "true" && -n "$PHASE" ]]; then
  PHASE_LOWER=$(echo "$PHASE" | tr '[:upper:]' '[:lower:]')

  # Map phase names to file names
  case "$PHASE_LOWER" in
    define) FILE="define.md" ;;
    build)  FILE="build.md" ;;
    harden) FILE="harden.md" ;;
    ship)   FILE="ship.md" ;;
    sustain) FILE="sustain.md" ;;
    *) exit 0 ;;
  esac

  jq -n --arg file "$FILE" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("PHASE LOADING REQUIRED: Read phases/" + $file + " before dispatching agents. Mark phase_file_loaded=true in state.json after reading.")
    }
  }'
else
  exit 0
fi
