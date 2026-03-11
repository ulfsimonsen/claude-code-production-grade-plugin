#!/usr/bin/env bash
# Production-Grade Session Guard
# Detects if the current project was built with production-grade and offers
# the user a choice: work with the pipeline or without it.
#
# Reads hook input from stdin (JSON with source, session_id, etc.)
# If source is "compact" or "clear" during an active pipeline, outputs a
# short re-orientation message instead of the full guard prompt.
#
# Sets CLAUDE_CODE_EFFORT_LEVEL=high via CLAUDE_ENV_FILE when a pipeline
# is active — ensures Sonnet 4.6 and Opus 4.6 don't abbreviate critical
# pipeline steps (gate verification, receipt writing, re-anchoring).

SUITE_DIR="Claude-Production-Grade-Suite"

# Only fire if the suite directory exists in the current project
if [ ! -d "$SUITE_DIR" ]; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)

# Extract source field (startup|resume|clear|compact)
SOURCE=$(echo "$INPUT" | grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# Set high effort for production-grade projects via CLAUDE_ENV_FILE.
# CLAUDE_ENV_FILE is only available in SessionStart hooks — it persists
# environment variables for the session's Bash commands and model effort.
# Known issue: CLAUDE_ENV_FILE may be empty for plugin-provided hooks
# (GitHub #11649). The guard still works — effort just won't auto-set.
if [ -n "$CLAUDE_ENV_FILE" ] && [ -w "$CLAUDE_ENV_FILE" ]; then
  echo 'export CLAUDE_CODE_EFFORT_LEVEL=high' >> "$CLAUDE_ENV_FILE"
fi

# During compaction, clear, or resume, check if a pipeline is actively running.
# If so, output a short re-orientation message instead of the full guard.
# "resume" added per Claude Code 2.1.73 — SessionStart hooks now fire once
# (not twice) on --resume/--continue. Active pipelines should re-orient, not
# re-prompt.
if [ "$SOURCE" = "compact" ] || [ "$SOURCE" = "clear" ] || [ "$SOURCE" = "resume" ]; then
  if [ -f "$SUITE_DIR/.orchestrator/settings.md" ]; then
    # Check if pipeline already completed (pipeline-status marker)
    if [ -f "$SUITE_DIR/.orchestrator/pipeline-status" ]; then
      STATUS_CONTENT=$(cat "$SUITE_DIR/.orchestrator/pipeline-status" 2>/dev/null)
      if echo "$STATUS_CONTENT" | grep -qx "complete\|rejected"; then
        # Pipeline is done — fall through to normal guard
        :
      else
        # Pipeline active — short message
        cat <<REORIENT
# Production-Grade Pipeline Active

Context was compacted during an active pipeline run. **Do not re-prompt the user about using production-grade.**

Re-orient by reading these files from disk:
- \`$SUITE_DIR/.orchestrator/settings.md\` — engagement mode and parallelism
- \`$SUITE_DIR/.orchestrator/receipts/\` — latest completed receipts (check which tasks are done)
- The current phase dispatcher file for the active phase

Continue the pipeline from where you left off.
REORIENT
        exit 0
      fi
    else
      # settings.md exists but no pipeline-status — pipeline is in progress
      cat <<REORIENT
# Production-Grade Pipeline Active

Context was compacted during an active pipeline run. **Do not re-prompt the user about using production-grade.**

Re-orient by reading these files from disk:
- \`$SUITE_DIR/.orchestrator/settings.md\` — engagement mode and parallelism
- \`$SUITE_DIR/.orchestrator/receipts/\` — latest completed receipts (check which tasks are done)
- The current phase dispatcher file for the active phase

Continue the pipeline from where you left off.
REORIENT
      exit 0
    fi
  fi
fi

# Count artifacts for context
ADR_COUNT=$(find "$SUITE_DIR" -name "ADR-*.md" 2>/dev/null | wc -l | tr -d ' ')
RECEIPT_COUNT=$(find "$SUITE_DIR/.orchestrator/receipts" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
PROTOCOL_COUNT=$(find "$SUITE_DIR/.protocols" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

cat <<GUARD
# Production-Grade Native Project Detected

This project was built with the production-grade pipeline. The \`$SUITE_DIR/\` directory contains ${ADR_COUNT} architecture decisions, ${RECEIPT_COUNT} pipeline receipts, and ${PROTOCOL_COUNT} protocols.

**IMPORTANT — Before starting work, ask the user how they'd like to proceed using AskUserQuestion:**

Question: "This project was built with the production-grade pipeline. How would you like to work today?"
Header: "Production-Grade Native Project"
Options:
  1. "Use production-grade (Recommended)" — "Route changes through specialized agents — architecture, security, and test baselines stay intact. Best for features, refactors, and anything that touches system behavior."
  2. "Work directly without the plugin" — "Make changes freely. Good for quick fixes, experiments, or when you know exactly what you're changing. You can always invoke /production-grade later if needed."
  3. "Chat about this" — "Let's discuss what I'm planning and figure out the best approach together."

If the user chooses option 1: invoke /production-grade for their request — it auto-routes to the right mode (Feature, Review, Test, Harden, Ship, Architect, Explore, Optimize).
If the user chooses option 2: proceed normally. Respect the choice fully — no further reminders this session.
If the user chooses option 3: discuss their plans, then recommend an approach.

**Context for the user if they ask why:** This project has ${ADR_COUNT} architecture decisions, ${RECEIPT_COUNT} verified pipeline receipts, and ${PROTOCOL_COUNT} shared protocols. The plugin ensures changes respect these baselines — but it's always your call.
GUARD
