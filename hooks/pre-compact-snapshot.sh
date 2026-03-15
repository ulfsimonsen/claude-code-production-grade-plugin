#!/bin/bash
# PreCompact hook: Snapshots critical pipeline state BEFORE compaction
# destroys context. Creates a recovery point for PostCompact re-orientation.
# Requires: jq

SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

# Snapshot state to a compact-safe file
SNAPSHOT="$SUITE_DIR/.orchestrator/pre-compact-snapshot.json"
cp "$STATE_FILE" "$SNAPSHOT"

# Count current receipts for post-compact re-orientation
RECEIPT_COUNT=$(find "$SUITE_DIR/.orchestrator/receipts" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')

# Collect receipt filenames for quick re-orientation
RECEIPT_LIST=$(find "$SUITE_DIR/.orchestrator/receipts" -name "*.json" 2>/dev/null | sort | while read -r f; do basename "$f" .json; done | paste -sd',' -)

jq --argjson rc "$RECEIPT_COUNT" \
   --arg rl "$RECEIPT_LIST" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '. + {
     receipt_count_at_compact: $rc,
     receipts_at_compact: $rl,
     compacted_at: $ts
   }' "$SNAPSHOT" > "${SNAPSHOT}.tmp" && mv "${SNAPSHOT}.tmp" "$SNAPSHOT"

exit 0
