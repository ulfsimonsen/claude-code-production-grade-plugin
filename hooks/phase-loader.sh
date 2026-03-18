#!/bin/bash
# PreToolUse(Agent) hook: DENIES agent dispatch when phase file not loaded.
# Graduated enforcement: deny twice, then allow+inject critical directives.
# This is the structural enforcement mechanism — prose reminders failed.
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

  # --- Graduated deny enforcement ---
  DENY_DIR="$SUITE_DIR/.orchestrator"
  DENY_FILE="$DENY_DIR/.deny-count-${PHASE_LOWER}"
  mkdir -p "$DENY_DIR"

  # Read current deny count
  DENY_COUNT=0
  if [[ -f "$DENY_FILE" ]]; then
    DENY_COUNT=$(cat "$DENY_FILE" 2>/dev/null)
    # Sanitize to integer
    DENY_COUNT=$((DENY_COUNT + 0))
  fi

  if [[ "$DENY_COUNT" -ge 2 ]]; then
    # Fallback: allow but inject critical directives to prevent deadlock
    CRITICAL_FILE=""
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
      CRITICAL_FILE="${CLAUDE_PLUGIN_ROOT}/skills/production-grade/phases/critical/${PHASE_LOWER}-critical.txt"
    fi

    CRITICAL_CONTENT=""
    if [[ -n "$CRITICAL_FILE" && -f "$CRITICAL_FILE" ]]; then
      CRITICAL_CONTENT=$(cat "$CRITICAL_FILE" 2>/dev/null)
    fi

    FALLBACK_MSG="PHASE ENFORCEMENT FALLBACK: Agent dispatch allowed after ${DENY_COUNT} denials. The phase file phases/${FILE} was NOT read. MANDATORY steps for ${PHASE} phase injected below."
    if [[ -n "$CRITICAL_CONTENT" ]]; then
      FALLBACK_MSG="${FALLBACK_MSG} --- CRITICAL DIRECTIVES (${PHASE}): ${CRITICAL_CONTENT}"
    fi

    # Increment counter for tracking
    echo "$((DENY_COUNT + 1))" > "$DENY_FILE"

    jq -n --arg msg "$FALLBACK_MSG" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        additionalContext: $msg
      }
    }'
  else
    # DENY the Agent() call — force orchestrator to read phase file first
    echo "$((DENY_COUNT + 1))" > "$DENY_FILE"

    jq -n --arg file "$FILE" --arg count "$((DENY_COUNT + 1))" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        additionalContext: ("Agent dispatch BLOCKED (attempt " + $count + "/2). Read phases/" + $file + " and set phase_file_loaded=true in state.json before dispatching agents.")
      }
    }'
  fi
else
  # Phase loaded or no phase — clean pass-through
  # Reset deny counter when phase is loaded (transition completed)
  if [[ "$LOADED" == "true" && -n "$PHASE" ]]; then
    PHASE_LOWER=$(echo "$PHASE" | tr '[:upper:]' '[:lower:]')
    DENY_FILE="$SUITE_DIR/.orchestrator/.deny-count-${PHASE_LOWER}"
    [[ -f "$DENY_FILE" ]] && rm -f "$DENY_FILE"
  fi
  exit 0
fi
