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
#
# v7.0.0: Added resume source handling (SessionStart now fires on --resume
# via Claude Code 2.1.73+). Added CLAUDE_PLUGIN_DATA awareness to detect
# returning users with saved preferences.

SUITE_DIR="Claude-Production-Grade-Suite"

# Only fire if the suite directory exists in the current project
if [ ! -d "$SUITE_DIR" ]; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)

# Extract source field (startup|resume|clear|compact)
SOURCE=$(echo "$INPUT" | grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# CLAUDE_PLUGIN_DATA awareness: detect returning user with saved preferences.
# If preferences.json exists, the user has prior saved defaults — this informs
# the guard message so we don't re-ask settings they already configured.
RETURNING_USER=false
if [ -n "$CLAUDE_PLUGIN_DATA" ] && [ -f "$CLAUDE_PLUGIN_DATA/preferences.json" ]; then
  RETURNING_USER=true
fi

# Set high effort for production-grade projects via CLAUDE_ENV_FILE.
# CLAUDE_ENV_FILE is only available in SessionStart hooks — it persists
# environment variables for the session's Bash commands and model effort.
# Known issue: CLAUDE_ENV_FILE may be empty for plugin-provided hooks
# (GitHub #11649). The guard still works — effort just won't auto-set.
if [ -n "$CLAUDE_ENV_FILE" ] && [ -w "$CLAUDE_ENV_FILE" ]; then
  echo 'export CLAUDE_CODE_EFFORT_LEVEL=high' >> "$CLAUDE_ENV_FILE"
fi

# --- Layer 4: Cleanup-pending detection on session start ---
# If a prior session ended mid-pipeline, a cleanup-pending marker exists.
# Inject cleanup instructions so the orchestrator executes TeamDelete and
# other critical steps that were missed.
CLEANUP_PENDING_FILE="$SUITE_DIR/.orchestrator/cleanup-pending"
if [ -f "$CLEANUP_PENDING_FILE" ]; then
  if [ "$SOURCE" = "startup" ] || [ "$SOURCE" = "resume" ]; then
    CLEANUP_CONTENT=$(cat "$CLEANUP_PENDING_FILE" 2>/dev/null)
    cat <<CLEANUP
# Pipeline Cleanup Required

A prior pipeline session ended without completing cleanup. The following steps are **MANDATORY** before starting new work:

1. **Run \`TeamDelete(team_name="production-grade")\`** to free any orphaned agents
2. **Check CLAUDE.md** for the Production-Grade Native directive — write it if missing
3. **Write pipeline analytics** to CLAUDE_PLUGIN_DATA if preferences are available
4. **Update pipeline-status** marker from "partial" to "complete" after cleanup

Prior session details:
\`\`\`
${CLEANUP_CONTENT}
\`\`\`

After completing cleanup, delete the marker file: \`$CLEANUP_PENDING_FILE\`
CLEANUP
    exit 0
  fi
fi

# During clear or resume, check if a pipeline is actively running.
# If so, output a short re-orientation message instead of the full guard.
# "resume" added per Claude Code 2.1.73 — SessionStart hooks now fire once
# (not twice) on --resume/--continue. Active pipelines should re-orient, not
# re-prompt.
# Note: "compact" is handled by the PostCompact hook (post-compact-guard.sh)
# since 2.1.76. PostCompact fires AFTER compaction, so the re-orientation
# message survives intact instead of being compressed.
if [ "$SOURCE" = "clear" ] || [ "$SOURCE" = "resume" ]; then
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

# Build returning-user note for the guard message
RETURNING_NOTE=""
if [ "$RETURNING_USER" = "true" ]; then
  RETURNING_NOTE="
Note: This user has saved preferences in CLAUDE_PLUGIN_DATA/preferences.json. Their defaults (engagement mode, parallelism, worktrees) will be auto-applied when the pipeline starts — no need to re-ask about those settings."
fi

cat <<GUARD
# Production-Grade Native Project Detected

This project was built with the production-grade pipeline. The \`$SUITE_DIR/\` directory contains ${ADR_COUNT} architecture decisions, ${RECEIPT_COUNT} pipeline receipts, and ${PROTOCOL_COUNT} protocols.
${RETURNING_NOTE}
**IMPORTANT — Before starting work, ask the user how they'd like to proceed using Elicitation:**

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
