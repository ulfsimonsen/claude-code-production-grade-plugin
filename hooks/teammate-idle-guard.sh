#!/usr/bin/env bash
# Production-Grade Teammate Idle Guard
# Stops idle teammates when the pipeline is complete or rejected.
# This is a safety net — primary cleanup is TeamDelete in the orchestrator SKILL.md.
# Without this, orphaned teammates idle forever if the orchestrator loses context.

SUITE_DIR="Claude-Production-Grade-Suite"

# If no suite directory, not a production-grade project — let teammate continue
if [ ! -d "$SUITE_DIR" ]; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)

# Extract team_name from hook input
TEAM_NAME=$(echo "$INPUT" | grep -o '"team_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"team_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# Only act on production-grade teammates
if [ "$TEAM_NAME" != "production-grade" ]; then
  exit 0
fi

# Check 1: pipeline-status marker (written by orchestrator on completion or rejection)
if [ -f "$SUITE_DIR/.orchestrator/pipeline-status" ]; then
  STATUS=$(cat "$SUITE_DIR/.orchestrator/pipeline-status" 2>/dev/null)
  if echo "$STATUS" | grep -qx "complete\|rejected"; then
    echo '{"continue": false, "stopReason": "Production-grade pipeline finished — stopping idle teammate"}'
    exit 0
  fi
fi

# Check 2: T13 receipt exists (compound learning + assembly — final task)
if ls "$SUITE_DIR/.orchestrator/receipts"/T13-* 1>/dev/null 2>&1; then
  echo '{"continue": false, "stopReason": "Production-grade pipeline complete (T13 receipt found) — stopping idle teammate"}'
  exit 0
fi

# Pipeline still running — let teammate continue
echo '{"continue": true}'
exit 0
