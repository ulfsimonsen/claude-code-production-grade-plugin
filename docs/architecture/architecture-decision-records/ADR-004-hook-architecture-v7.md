# ADR-004: Hook Architecture v7.0.0

**Status:** Accepted
**Context:** US-7 requires integrating 8+ new Claude Code hook events. Current hooks.json has 8 entries with 9 scripts. Decision: one script per hook event for maximum separation.

## New Hook Events and Scripts

### Current (v6.0.0) — 8 entries, 9 scripts

| Event | Script | Purpose |
|---|---|---|
| SessionStart | session-guard.sh | Project detection, effort auto-set |
| PostCompact | post-compact-guard.sh | Re-inject pipeline state |
| TeammateIdle | teammate-idle-guard.sh | Teammate lifecycle |
| SubagentStart | subagent-phase-injector.sh | Phase context injection |
| TaskCompleted | task-gate-validator.sh | Receipt verification |
| PreCompact | pre-compact-snapshot.sh | Pipeline state snapshot |
| PreToolUse (Agent) | phase-loader.sh | Phase file loading reminder |
| PostToolUse (Write) | receipt-validator.sh | Receipt JSON validation |

### New (v7.0.0) — 7 new entries, 7 new scripts

| Event | Script | Purpose |
|---|---|---|
| StopFailure | stop-failure-guard.sh | Catch API errors, log, optionally trigger retry |
| InstructionsLoaded | instructions-loaded-guard.sh | Load CLAUDE_PLUGIN_DATA preferences |
| PreToolUse (Elicitation) | elicitation-validator.sh | Validate elicitation forms |
| PostToolUse (ElicitationResult) | elicitation-result-logger.sh | Log/transform user responses |
| WorktreeCreate | worktree-create-tracker.sh | Track worktree lifecycle |
| WorktreeRemove | worktree-remove-tracker.sh | Worktree cleanup verification |
| Stop | pipeline-cleanup.sh | Graceful pipeline cleanup on stop |

### Updated (v7.0.0) — 3 existing scripts modified

| Script | Change |
|---|---|
| subagent-phase-injector.sh | Use `agent_id` and `agent_type` fields from hook input for per-agent context. Add `worktree` field awareness. |
| session-guard.sh | Add `resume` to matcher (2.1.78 supports resume event). Read CLAUDE_PLUGIN_DATA for returning user detection. |
| hooks.json | Add 7 new entries. Update SessionStart matcher to `startup\|clear\|resume`. |

### hooks.json v7.0.0 Structure

Total: 15 hook entries, 16 scripts (9 existing + 7 new)

### Script Conventions (maintained from v6.0.0)

- All scripts start with: `_R="${CLAUDE_PLUGIN_ROOT}"; [ -z "$_R" ] && exit 0;`
- Guard: only fire if pipeline is active (check state.json)
- Guard: jq must be available
- Output: JSON to stdout via `jq -n`
- Timeout: 5-10 seconds per script

**Consequences:**
- 7 new .sh files in hooks/ directory (16 total)
- hooks.json grows from 8 to 15 entries
- Test suite needs 7 new test files (or extend existing test-hooks-json.sh)
- One script per event is verbose but maximizes clarity and testability

**Alternatives Considered:**
- Extend existing scripts with case statements: Rejected — user preference for maximum separation
- Consolidate into fewer scripts: Rejected — harder to test, harder to understand
