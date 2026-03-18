#!/bin/bash
# WorktreeRemove hook: Removes a worktree from the active_worktrees array in
# state.json when Claude Code deletes it. Keeps the orchestrator's worktree
# tracking accurate throughout the pipeline run.
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

[[ -z "$WORKTREE_PATH" ]] && exit 0

# Remove worktree from active_worktrees array by path (flock prevents race conditions)
(
  flock -x 200
  jq --arg path "$WORKTREE_PATH" \
    '.active_worktrees = ((.active_worktrees // []) | map(select(.path != $path)))' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
) 200>"${STATE_FILE}.lock"

CONTEXT="Worktree removed from tracking: path=${WORKTREE_PATH}, branch=${BRANCH:-unknown}."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "WorktreeRemove",
    additionalContext: $ctx
  }
}'
