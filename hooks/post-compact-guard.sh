#!/usr/bin/env bash
# Production-Grade Post-Compact Guard
# Fires AFTER context compaction completes (PostCompact hook).
# Injects pipeline state summary so the orchestrator can re-orient
# without re-reading every file from disk.
#
# Unlike the SessionStart "compact" handler (which fires BEFORE compaction
# and may itself get compressed), PostCompact output survives intact because
# it's injected into the fresh post-compaction context.
#
# Requires Claude Code 2.1.76+ (PostCompact hook support).

SUITE_DIR="Claude-Production-Grade-Suite"

# Only fire if the suite directory exists in the current project
if [ ! -d "$SUITE_DIR" ]; then
  exit 0
fi

# Check if pipeline already completed — no re-orientation needed
if [ -f "$SUITE_DIR/.orchestrator/pipeline-status" ]; then
  STATUS_CONTENT=$(cat "$SUITE_DIR/.orchestrator/pipeline-status" 2>/dev/null)
  if echo "$STATUS_CONTENT" | grep -qx "complete\|rejected"; then
    exit 0
  fi
fi

# Check if pipeline is active (settings.md exists = pipeline was started)
if [ ! -f "$SUITE_DIR/.orchestrator/settings.md" ]; then
  exit 0
fi

# --- Gather pipeline state from disk ---

# Read settings
SETTINGS=$(cat "$SUITE_DIR/.orchestrator/settings.md" 2>/dev/null)
ENGAGEMENT=$(echo "$SETTINGS" | grep -o 'Engagement: [a-zA-Z]*' | head -1 | cut -d' ' -f2)
PARALLELISM=$(echo "$SETTINGS" | grep -o 'Parallelism: [a-zA-Z]*' | head -1 | cut -d' ' -f2)
WORKTREES=$(echo "$SETTINGS" | grep -o 'Worktrees: [a-zA-Z]*' | head -1 | cut -d' ' -f2)

# Count completed receipts and identify the last one
RECEIPT_DIR="$SUITE_DIR/.orchestrator/receipts"
if [ -d "$RECEIPT_DIR" ]; then
  RECEIPT_COUNT=$(find "$RECEIPT_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  LAST_RECEIPT=$(ls -t "$RECEIPT_DIR"/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null)
else
  RECEIPT_COUNT=0
  LAST_RECEIPT="none"
fi

# Determine current wave from receipt patterns
# Wave A: T3a, T3b, T4a, T5a, T6a, T6b, T9a, T11a, T12
# Wave B: T4b, T5b, T6c, T6d, T7
# Wave C: T8, T9b, T10
# Wave D: T11b, T13
CURRENT_WAVE="unknown"
NEXT_DISPATCHER="unknown"

if ls "$RECEIPT_DIR"/T13-* 1>/dev/null 2>&1; then
  CURRENT_WAVE="SUSTAIN (complete)"
  NEXT_DISPATCHER="none — pipeline complete"
elif ls "$RECEIPT_DIR"/T8-* 1>/dev/null 2>&1 || ls "$RECEIPT_DIR"/T9b-* 1>/dev/null 2>&1; then
  CURRENT_WAVE="Wave C (SHIP)"
  NEXT_DISPATCHER="phases/sustain.md (Wave D)"
elif ls "$RECEIPT_DIR"/T5b-* 1>/dev/null 2>&1 || ls "$RECEIPT_DIR"/T6c-* 1>/dev/null 2>&1 || ls "$RECEIPT_DIR"/T7-* 1>/dev/null 2>&1; then
  CURRENT_WAVE="Wave B (HARDEN + IaC)"
  NEXT_DISPATCHER="phases/ship.md (Wave C)"
elif ls "$RECEIPT_DIR"/T3a-* 1>/dev/null 2>&1 || ls "$RECEIPT_DIR"/T3b-* 1>/dev/null 2>&1; then
  CURRENT_WAVE="Wave A (BUILD + analysis)"
  NEXT_DISPATCHER="phases/harden.md (Wave B)"
elif ls "$RECEIPT_DIR"/T2-* 1>/dev/null 2>&1; then
  CURRENT_WAVE="DEFINE (architecture complete)"
  NEXT_DISPATCHER="phases/build.md (Wave A)"
elif ls "$RECEIPT_DIR"/T1-* 1>/dev/null 2>&1; then
  CURRENT_WAVE="DEFINE (BRD complete)"
  NEXT_DISPATCHER="phases/define.md (Gate 1 → T2)"
else
  CURRENT_WAVE="DEFINE (starting)"
  NEXT_DISPATCHER="phases/define.md (T1)"
fi

# Check for pending gate (rework log)
PENDING_GATE=""
if [ -f "$SUITE_DIR/.orchestrator/rework-log.md" ]; then
  PENDING_GATE=$(grep -c "^## Gate" "$SUITE_DIR/.orchestrator/rework-log.md" 2>/dev/null)
  if [ "$PENDING_GATE" -gt 0 ]; then
    PENDING_GATE=" (rework log: $PENDING_GATE cycles)"
  else
    PENDING_GATE=""
  fi
fi

cat <<REORIENT
# Production-Grade Pipeline — Post-Compaction Re-Orientation

Context was compacted during an active pipeline run. **Do not re-prompt the user about using production-grade.**

## Pipeline State
- **Current:** ${CURRENT_WAVE}${PENDING_GATE}
- **Next dispatcher:** \`${NEXT_DISPATCHER}\`
- **Receipts:** ${RECEIPT_COUNT} completed (last: ${LAST_RECEIPT})
- **Settings:** ${ENGAGEMENT:-Standard} engagement, ${PARALLELISM:-Maximum} parallelism, Worktrees: ${WORKTREES:-enabled}

## Re-Anchor From Disk
Read these files to restore full context:
- \`$SUITE_DIR/.orchestrator/settings.md\` — engagement mode, parallelism, worktrees
- \`$SUITE_DIR/.orchestrator/receipts/\` — all completed task receipts
- The next dispatcher file listed above

**Continue the pipeline from where you left off. Do not restart completed tasks.**
REORIENT
