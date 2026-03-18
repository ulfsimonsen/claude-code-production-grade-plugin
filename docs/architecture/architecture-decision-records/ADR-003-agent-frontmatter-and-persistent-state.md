# ADR-003: Agent Frontmatter Configuration & Persistent State

**Status:** Accepted
**Context:** US-5 requires migrating agent configuration from runtime `model` params to SKILL.md frontmatter (`effort`, `maxTurns`, `disallowedTools`). US-6 requires persistent plugin state via `${CLAUDE_PLUGIN_DATA}`. US-7 requires new hook events including `InstructionsLoaded`.

## Decision 1: Agent Frontmatter

Every agent SKILL.md gains three new frontmatter fields (Claude Code 2.1.78):

```yaml
---
name: code-reviewer
description: >
  [production-grade internal] Reviews code for quality...
effort: high
maxTurns: 3
disallowedTools:
  - Write
  - Edit
  - Bash
---
```

### Frontmatter Configuration Table

| Agent | effort | maxTurns | disallowedTools |
|---|---|---|---|
| production-grade (orchestrator) | high | — | — |
| product-manager | high | 5 | — |
| solution-architect | high | 8 | — |
| software-engineer | high | 15 | — |
| frontend-engineer | high | 15 | — |
| qa-engineer | high | 10 | — |
| security-engineer | high | 5 | [Write, Edit] |
| code-reviewer | high | 3 | [Write, Edit, Bash] |
| devops | high | 10 | — |
| sre | high | 5 | — |
| data-scientist | high | 5 | — |
| technical-writer | high | 8 | — |
| skill-maker | high | 5 | — |
| polymath | high | 5 | — |
| evaluator (NEW) | high | 3 | [Write, Edit] |

**Key decisions:**
- `effort: high` for ALL agents — pipeline work is always high-effort
- Analysis-only agents (code-reviewer, security-engineer, evaluator) have `disallowedTools: [Write, Edit]` to enforce read-only behavior structurally
- code-reviewer additionally disallows Bash to prevent any side effects
- Build agents (software-engineer, frontend-engineer, devops) have no disallowedTools — they need full capability
- `maxTurns` scales with expected output volume: builders get 15, analysts get 3-5

### Runtime Override

Phase dispatchers NO LONGER pass `model` param on Agent() calls. Frontmatter is the single source of truth. The `Model-Optimization` setting in settings.md controls whether frontmatter is active (always yes for v7.0.0, but retained for debugging).

## Decision 2: Persistent State via CLAUDE_PLUGIN_DATA

### InstructionsLoaded Hook

New hook script: `hooks/instructions-loaded-guard.sh`
- Fires on `InstructionsLoaded` event (Claude Code 2.1.69+)
- Reads `${CLAUDE_PLUGIN_DATA}/preferences.json`
- If preferences exist: writes defaults to `Claude-Production-Grade-Suite/.orchestrator/settings.md`
- If no preferences: does nothing (first-run path)
- The orchestrator detects pre-populated settings and offers "reuse last preferences?" via Elicitation

### Data Layout

```
${CLAUDE_PLUGIN_DATA}/
├── preferences.json          # User defaults (engagement, parallelism, worktree, model)
└── analytics/
    ├── {project-slug-1}.json  # Per-project pipeline history
    ├── {project-slug-2}.json
    └── ...
```

### preferences.json Schema

```json
{
  "engagement": "thorough",
  "parallelism": "maximum",
  "worktrees": true,
  "model_optimization": true,
  "last_updated": "2026-03-18T14:00:00Z"
}
```

### Analytics Schema (per-project)

```json
{
  "project_slug": "production-grade-plugin",
  "runs": [
    {
      "timestamp": "2026-03-18T14:00:00Z",
      "mode": "full-build",
      "engagement": "thorough",
      "duration_seconds": 720,
      "agents_spawned": 14,
      "tasks_completed": 13,
      "tasks_failed": 0,
      "findings_critical": 0,
      "findings_high": 2
    }
  ]
}
```

### Pipeline Integration

1. **Start**: InstructionsLoaded hook populates settings.md from preferences
2. **Engagement mode question**: If preferences exist, first option is "Reuse last settings (Recommended)"
3. **End**: sustain.md writes updated preferences + analytics to CLAUDE_PLUGIN_DATA
4. **Final summary**: Shows "This is your Nth pipeline run. Average time: Xm."

**Consequences:**
- New dependency: `${CLAUDE_PLUGIN_DATA}` env var (2.1.78+). If missing, plugin works without persistence.
- Analytics grows linearly with pipeline runs — 1-2KB per run, negligible.
- InstructionsLoaded hook adds ~5ms to startup. Acceptable.

**Alternatives Considered:**
- SessionStart hook for preference loading: Rejected — InstructionsLoaded fires after skills are loaded, giving more context about what's being invoked.
- Skill-level loading: Rejected — duplicates logic across 14 skills.
