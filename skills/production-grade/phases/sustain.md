# Wave D — Dispatcher

This phase manages Wave D: T11b (Technical Writer — ops guide) and T13 (Compound Learning + Final Assembly). Also collects T12 (Skill Maker) results from Wave A background if completed.

## Visual Output

Print pipeline dashboard with SUSTAIN ● active on phase start:
```
  → Starting Wave D (ops guide + final assembly)
```

On completion:
```
┌─ WAVE D COMPLETE ─────────────────────── ⏱ {time} ─┐
│                                                      │
│  ✓ Technical Writer  ops guide ({N} docs)            │
│  ✓ Skill Maker       {N} project-specific skills     │
│  ✓ Assembly          final validation complete       │
│                                                      │
│  → Presenting final summary                          │
└──────────────────────────────────────────────────────┘
```

## Re-Anchor

Before creating Wave D agent tasks, re-read from disk:
- All receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/` (complete pipeline history for compound learning)
- `Claude-Production-Grade-Suite/sre/` output (T9b — needed for ops guide)
- `infrastructure/` listing, `.github/workflows/` listing
- `docs/architecture/` listing
- Check for T12 receipt: `Claude-Production-Grade-Suite/.orchestrator/receipts/T12-skill-maker.json` — if it exists, T12 completed during Wave A background. If not, T12 is still running or failed.
- Check for T11a receipt: `Claude-Production-Grade-Suite/.orchestrator/receipts/T11a-techwriter-api.json` — API ref should be done from Wave A background.

## Collect Background Agent Results

```python
# Check T12 (Skill Maker) — launched as background in Wave A
t12_receipt = Read("Claude-Production-Grade-Suite/.orchestrator/receipts/T12-skill-maker.json")
if t12_receipt:
  # T12 completed — skills are staged at Claude-Production-Grade-Suite/skill-maker/skills/
  t12_complete = True
else:
  # T12 still running or failed — wait briefly, then proceed without
  print("  ⧖ T12 (Skill Maker) not yet complete — will check again after T11b")
  t12_complete = False

# Check T11a (API ref) — launched as background in Wave A
t11a_receipt = Read("Claude-Production-Grade-Suite/.orchestrator/receipts/T11a-techwriter-api.json")
if t11a_receipt:
  print("  ✓ T11a API reference available from Wave A")
```

## T11b: Technical Writer — Ops Guide

T11b writes the operational guide, which needs SRE output (T9b) and infrastructure (T7). The API reference (T11a) was already written in Wave A background.

```python
TaskUpdate(taskId=t11b_id, status="in_progress")
Agent(
  prompt="""You are the Technical Writer — Operations Guide.
Use the Skill tool to invoke 'production-grade:technical-writer' to load your methodology.
Read SRE output from: Claude-Production-Grade-Suite/sre/ (SLOs, chaos scenarios, runbooks)
Read infrastructure from: infrastructure/, .github/workflows/
Read architecture from: docs/architecture/
Read .production-grade.yaml for paths and preferences.

Note: API reference and developer guides were already written by T11a in Wave A.
Read T11a output from: Claude-Production-Grade-Suite/technical-writer/api-reference/ and guides/
Your job: write the OPERATIONAL guide only — deployment procedures, monitoring, incident response, runbook index.

If features.documentation_site is true: update the Docusaurus scaffold with ops guide section.
Write ops guide to project root: docs/ops-guide/
Write workspace artifacts to: Claude-Production-Grade-Suite/technical-writer/
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T11b-techwriter-ops.json.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier
  isolation="worktree"  # Omit if Worktrees: disabled
)
```

## Worktree Merge-Back

```python
if t11b_branch:
  Bash(f"git merge --no-ff {t11b_branch} -m 'production-grade: merge {t11b_branch}'")
  Bash(f"git branch -d {t11b_branch}")
# Stale worktrees auto-cleaned (2.1.76+). Merge conflicts escalated to user.
```

## T13: Compound Learning + Final Assembly

After T11b completes (and worktree branch is merged):

```python
TaskUpdate(taskId=t13_id, status="in_progress")
```

### Collect T12 (if not already done)

```python
if not t12_complete:
  t12_receipt = Read("Claude-Production-Grade-Suite/.orchestrator/receipts/T12-skill-maker.json")
  if t12_receipt:
    t12_complete = True
  else:
    # T12 didn't complete — log and proceed without custom skills
    print("  ⚠ T12 (Skill Maker) did not complete — skipping custom skills")
```

### Compound Learning

Write to `Claude-Production-Grade-Suite/.orchestrator/compound-learnings.md`:

```markdown
## Learning: [date] — [project name]

### What Worked
- [patterns, decisions, tools that worked well]

### What Failed
- [errors encountered, root causes, how they were fixed]

### Architecture Insights
- [patterns that emerged, tech stack fit/misfit]

### Time Sinks
- [phases that took longest, what slowed them down]
- **Use receipt timestamps:** Read `completed_at` from each receipt in `Claude-Production-Grade-Suite/.orchestrator/receipts/`. Compute per-wave wall-clock time as `max(completed_at) - min(completed_at)` within each wave's receipts. Identify the slowest agent per wave and the longest wave overall. Report actual elapsed times, not estimates.

### Skip Next Time
- [unnecessary steps for this project type]

### Add Next Time
- [missing steps that should have been included]
```

### Production-Grade Native Directive (MANDATORY)

Write the following block to the project's `CLAUDE.md` (create if it doesn't exist, append if it does — but check for existing `# Production Grade Native` header first to avoid duplicates):

```markdown
# Production Grade Native

This project was built with the production-grade plugin. The `Claude-Production-Grade-Suite/` directory contains architecture decisions, security findings, test plans, and receipts from the build pipeline.

**At the start of every session, ask the user how they'd like to work.** Use AskUserQuestion:
- Header: "Production-Grade Native Project"
- Question: "This project was built with the production-grade pipeline. How would you like to work today?"
- Options:
  1. "Use production-grade (Recommended)" — "Route changes through specialized agents — architecture, security, and test baselines stay intact. Best for features, refactors, and anything that touches system behavior."
  2. "Work directly without the plugin" — "Make changes freely. Good for quick fixes, experiments, or when you know exactly what you're changing. You can always invoke /production-grade later if needed."
  3. "Chat about this" — "Let's discuss what I'm planning and figure out the best approach together."

If the user chooses production-grade, invoke `/production-grade` for their request — it auto-routes to the right mode (Feature, Review, Test, Harden, Ship, Architect, Explore, Optimize).

If the user chooses to work directly, respect that choice fully — no further reminders this session. They can always invoke `/production-grade` manually if they change their mind.

**Why this exists:** This project has architecture decisions (ADRs), API contracts, security baselines, and test coverage established by the pipeline. The production-grade plugin ensures changes go through the right specialized agents — but it's always the user's call. The plugin won't run the full pipeline for a feature request; it adapts to the scope of work.
```

**Why this is mandatory:** Without this directive, new Claude Code sessions treat the project as a regular codebase and make ad-hoc changes — violating ADRs, skipping tests, ignoring security baselines. The directive gives the user an informed choice at every session start.

Optionally also append key project patterns (tech stack, conventions, common commands) to CLAUDE.md for cross-session persistence.

### Final Assembly

1. **Integration decision** — ask user via AskUserQuestion:
```python
AskUserQuestion(questions=[{
  "question": "Code is ready. Integrate into your project root?",
  "header": "Assembly",
  "options": [
    {"label": "Integrate all code (Recommended)", "description": "Copy services, frontend, infra to project root"},
    {"label": "Keep in workspace only", "description": "Leave everything in Claude-Production-Grade-Suite/"},
    {"label": "Let me choose what to copy", "description": "Select which components to integrate"},
    {"label": "Chat about this", "description": "Discuss integration strategy"}
  ],
  "multiSelect": false
}])
```

2. **Install staged skills** — if T12 completed, inform user:
```
Skills staged to Claude-Production-Grade-Suite/skill-maker/skills/
To install: cp -r Claude-Production-Grade-Suite/skill-maker/skills/* .claude/skills/
(Sandbox blocks direct writes to .claude/skills/ — manual copy required)
```

3. **Run final validation:** `docker-compose up`, `make test`, `terraform validate`, health checks.

4. **Present final summary** using the orchestrator's template.

5. **Write pipeline status marker and clean up team:**
```python
TaskUpdate(taskId=t13_id, status="completed")
Bash("echo 'complete' > Claude-Production-Grade-Suite/.orchestrator/pipeline-status")
TeamDelete(team_name="production-grade")
```

## Pipeline Complete

Print the final summary template from the orchestrator. All tasks should show as completed in TaskList.
