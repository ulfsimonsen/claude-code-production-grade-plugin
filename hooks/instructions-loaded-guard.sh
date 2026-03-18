#!/bin/bash
# InstructionsLoaded hook: Reads user preferences from CLAUDE_PLUGIN_DATA
# and writes them into the orchestrator settings file so every pipeline run
# inherits the user's saved defaults (engagement mode, parallelism, etc.).
# Requires: jq

INPUT=$(cat)
_R="${CLAUDE_PLUGIN_ROOT}"; [ -z "$_R" ] && exit 0

SUITE_DIR="Claude-Production-Grade-Suite"

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

# Guard: CLAUDE_PLUGIN_DATA must be set and preferences.json must exist
PREFS_FILE=""
if [[ -n "$CLAUDE_PLUGIN_DATA" && -f "$CLAUDE_PLUGIN_DATA/preferences.json" ]]; then
  PREFS_FILE="$CLAUDE_PLUGIN_DATA/preferences.json"
else
  exit 0
fi

# Read preferences
ENGAGEMENT=$(jq -r '.engagement // empty' "$PREFS_FILE" 2>/dev/null)
PARALLELISM=$(jq -r '.parallelism // empty' "$PREFS_FILE" 2>/dev/null)
WORKTREES=$(jq -r '.worktrees // empty' "$PREFS_FILE" 2>/dev/null)
EFFORT=$(jq -r '.effort_level // empty' "$PREFS_FILE" 2>/dev/null)

# Only write settings if the orchestrator directory exists (pipeline started)
ORCH_DIR="$SUITE_DIR/.orchestrator"
SETTINGS_FILE="$ORCH_DIR/settings.md"

if [[ -d "$ORCH_DIR" && ! -f "$SETTINGS_FILE" ]]; then
  # Write defaults to settings.md only if it doesn't already exist
  cat > "$SETTINGS_FILE" <<EOF
# Pipeline Settings (from user preferences)

- Engagement: ${ENGAGEMENT:-thorough}
- Parallelism: ${PARALLELISM:-maximum}
- Worktrees: ${WORKTREES:-enabled}
- Effort: ${EFFORT:-high}
EOF
fi

SUMMARY="Preferences loaded from CLAUDE_PLUGIN_DATA: engagement=${ENGAGEMENT:-not set}, parallelism=${PARALLELISM:-not set}, worktrees=${WORKTREES:-not set}."

jq -n --arg ctx "$SUMMARY" '{
  hookSpecificOutput: {
    hookEventName: "InstructionsLoaded",
    additionalContext: $ctx
  }
}'
