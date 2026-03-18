#!/bin/bash
# WorktreeCreate hook: Tracks newly created worktrees in state.json so the
# orchestrator knows which branches are active and can route tasks to the
# correct worktree during parallel pipeline execution.
# Requires: jq

INPUT=$(cat)
_R="${CLAUDE_PLUGIN_ROOT}"; [ -z "$_R" ] && exit 0

SUITE_DIR="Claude-Production-Grade-Suite"
STATE_FILE="$SUITE_DIR/.orchestrator/state.json"

# Guard: only fire if pipeline is active
[[ ! -f "$STATE_FILE" ]] && exit 0

# Guard: jq must be available
command -v jq >/dev/null 2>&1 || exit 0

WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // .path // empty')
BRANCH=$(echo "$INPUT" | jq -r '.branch // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

[[ -z "$WORKTREE_PATH" ]] && exit 0

# Add worktree to state.json active_worktrees array
ENTRY=$(jq -n --arg path "$WORKTREE_PATH" --arg branch "$BRANCH" --arg ts "$TIMESTAMP" '{
  path: $path,
  branch: $branch,
  created_at: $ts
}')

# Atomic update: add entry if not already tracked by path (flock prevents race conditions)
(
  flock -x 200
  jq --argjson entry "$ENTRY" \
    '.active_worktrees = ((.active_worktrees // []) | map(select(.path != $entry.path)) + [$entry])' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
) 200>"${STATE_FILE}.lock"

CONTEXT="Worktree tracked: path=${WORKTREE_PATH}, branch=${BRANCH:-unknown}."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "WorktreeCreate",
    additionalContext: $ctx
  }
}'
