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

**At the start of every session, ask the user how they'd like to work.** Use Elicitation:
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

#### Auto Mode Assembly

If `Engagement: auto` in settings.md:

1. **Auto-integrate** — skip the question, integrate all code to project root immediately:
   ```
   ✓ Auto: integrated all code to project root
   ```
   Append to `Claude-Production-Grade-Suite/.orchestrator/auto-decisions.md`:
   `[T13] Auto-integrated all deliverables to project root — default for Auto mode`

2. **Install staged skills** — if T12 completed, log the staging location:
   ```
   ✓ Skills staged to Claude-Production-Grade-Suite/skill-maker/skills/
     To install: cp -r Claude-Production-Grade-Suite/skill-maker/skills/* .claude/skills/
   ```

3. **Run final validation:** `docker-compose up`, `make test`, `terraform validate`, health checks. Log results. If validation fails, log but do not block.

4. **Present Auto Mode final summary** (see SKILL.md Auto Mode — Final Summary Additions):
   - Read `Claude-Production-Grade-Suite/.orchestrator/auto-decisions.md` for the decisions log
   - Read all receipts for metrics and any `completed_with_errors` tasks
   - Collect unresolved findings as known issues
   - Print the Auto-specific summary with branch info, decisions log, and known issues

5. **Write pipeline status marker and clean up team:**
   ```python
   TaskUpdate(taskId=t13_id, status="completed")
   Bash("echo 'complete' > Claude-Production-Grade-Suite/.orchestrator/pipeline-status")
   TeamDelete(team_name="production-grade")
   ```

   Do NOT switch branches — leave user on the auto branch for review.

#### Standard Mode Assembly (non-Auto)

1. **Integration decision** — ask user via Elicitation:
```python
Elicitation(questions=[{
  "question": "Code is ready. Integrate into your project root?",
  "header": "Assembly",
  "options": [
    {"label": "Integrate all code (Recommended)", "description": "Copy services, frontend, infra to project root"},
    {"label": "Keep in workspace only", "description": "Leave everything in Claude-Production-Grade-Suite/"},
    {"label": "Let me choose what to copy", "description": "Select which components to integrate"},
    {"label": "Chat about this", "description": "Free-form text input about integration strategy"}
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

## Final Summary Template

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   ◆  PRODUCTION GRADE v{local_version} — COMPLETE    ⏱ {total}  ║
║   Project: {name}                                                ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║   DEFINE    ✓ BRD ({N} stories, {M} criteria)                    ║
║             ✓ Architecture ({pattern}, {N} services)             ║
║                                                                  ║
║   BUILD     ✓ Backend ({N} services, {M} endpoints, {K} lines)   ║
║             ✓ Frontend ({N} page groups, {M} components)         ║
║             ✓ Containers ({N} Dockerfiles, 1 compose)            ║
║                                                                  ║
║   HARDEN    ✓ Security ({N} findings → {M} Critical remaining)   ║
║             ✓ QA ({N} tests, {M}% passing)                       ║
║             ✓ Code Review ({N} findings → all resolved)          ║
║                                                                  ║
║   SHIP      ✓ Infrastructure (Terraform, {N} environments)       ║
║             ✓ CI/CD ({provider}, {N} workflows)                  ║
║             ✓ SRE ({N} SLOs, {M} alerts, {K} runbooks)          ║
║                                                                  ║
║   SUSTAIN   ✓ Documentation ({N} docs generated)                 ║
║             ✓ Custom Skills ({N} project-specific)               ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║   Agents: {N} used · Tasks: {M} completed · Errors: {K}         ║
║   Files: {N} created · Tests: {M} passing · Vulnerabilities: {K}║
║   Worktrees: {enabled|disabled} · Rework cycles: {N}            ║
║                                                                  ║
║   Cost       {N} agents · {M} total tool calls · {K} files      ║
║              Est. ~{X}K tokens · ~${A}-${B} at current pricing   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Cost Aggregation

Read ALL receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/`. For each receipt, extract:
- `effort` (files_read, files_written, tool_calls) — sum across all agents
- `completed_at` (ISO-8601) — compute per-wave elapsed time as `max(completed_at) - min(completed_at)`

Produce:
- Total agents used (count of unique receipt files)
- Total tool calls (sum of all effort.tool_calls)
- Total files processed (sum of effort.files_read + effort.files_written, deduplicated)
- Per-wave timing from receipt timestamps
- Total elapsed: earliest T1 completed_at to latest T13 completed_at
- Rework cycles from `.orchestrator/rework-log.md`

## Cron Monitoring Setup

After the final summary, offer to schedule automated monitoring tasks using Elicitation. Skip in Auto mode (log the offer to auto-decisions.md instead).

```python
# Only in Standard/Thorough/Express modes
if "Engagement: auto" not in settings:
  Elicitation(questions=[{
    "question": "Set up automated monitoring schedules for this project?",
    "header": "Cron Monitoring",
    "options": [
      {"label": "Set up all monitoring (Recommended)", "description": "Daily test re-runs, weekly security scans, weekly dependency checks"},
      {"label": "Choose schedules", "description": "Select which monitors to enable and customize schedules"},
      {"label": "Skip — I'll set up monitoring manually", "description": "No cron jobs created"},
      {"label": "Chat about this", "description": "Free-form text input about monitoring preferences"}
    ],
    "multiSelect": false
  }])
```

If the user opts in, schedule these jobs using `CronCreate`:

```python
project_slug = re.sub(r"[^a-z0-9-]", "-", project_name.lower())

# Daily post-pipeline test re-run
CronCreate(
  name=f"{project_slug}-daily-tests",
  schedule="0 6 * * *",  # 6am daily
  command=f"cd {project_root} && make test 2>&1 | tee Claude-Production-Grade-Suite/.orchestrator/cron-test-$(date +%Y%m%d).log"
)

# Weekly security scan
CronCreate(
  name=f"{project_slug}-weekly-security",
  schedule="0 7 * * 1",  # Monday 7am
  command=f"cd {project_root} && npm audit --audit-level=high 2>&1 | tee Claude-Production-Grade-Suite/.orchestrator/cron-security-$(date +%Y%m%d).log"
)

# Weekly dependency freshness check
CronCreate(
  name=f"{project_slug}-weekly-deps",
  schedule="0 8 * * 1",  # Monday 8am
  command=f"cd {project_root} && npm outdated 2>&1 | tee Claude-Production-Grade-Suite/.orchestrator/cron-deps-$(date +%Y%m%d).log"
)
```

Schedules are configurable via `.production-grade.yaml`:
```yaml
monitoring:
  daily_tests:
    enabled: true
    schedule: "0 6 * * *"
  weekly_security:
    enabled: true
    schedule: "0 7 * * 1"
  weekly_deps:
    enabled: true
    schedule: "0 8 * * 1"
```

## Persistent State

Write user preferences and pipeline analytics to `CLAUDE_PLUGIN_DATA` for cross-run persistence.

```python
import os, json
plugin_data = os.environ.get("CLAUDE_PLUGIN_DATA", "~/.claude/plugin-data/production-grade")
project_slug = re.sub(r"[^a-z0-9-]", "-", project_name.lower())

# Read settings from Claude-Production-Grade-Suite/.orchestrator/settings.md
# Extract engagement, parallelism, worktree, model preferences

# Write user preferences
prefs_path = f"{plugin_data}/preferences.json"
existing_prefs = json.loads(Read(prefs_path) or "{}")
prefs = {
  **existing_prefs,
  "last_project": project_slug,
  "last_run": datetime.utcnow().isoformat() + "Z",
  "engagement": settings.get("engagement", "thorough"),
  "parallelism": settings.get("parallelism", "maximum"),
  "worktrees": settings.get("worktrees", "enabled"),
  "model_optimization": settings.get("model_optimization", "enabled")
}
Write(prefs_path, json.dumps(prefs, indent=2))

# Write pipeline analytics
analytics_path = f"{plugin_data}/analytics/{project_slug}.json"
existing_analytics = json.loads(Read(analytics_path) or "{}")
run_count = existing_analytics.get("run_count", 0) + 1

# Compute timing from receipts
all_receipts = Glob("Claude-Production-Grade-Suite/.orchestrator/receipts/*.json")
timestamps = [json.loads(Read(r)).get("completed_at") for r in all_receipts if Read(r)]
timestamps = [t for t in timestamps if t]
total_elapsed_s = (max(timestamps) - min(timestamps)).total_seconds() if len(timestamps) >= 2 else 0
avg_elapsed_s = (existing_analytics.get("total_elapsed_s", 0) + total_elapsed_s) / run_count

analytics = {
  **existing_analytics,
  "run_count": run_count,
  "last_run": datetime.utcnow().isoformat() + "Z",
  "total_elapsed_s": existing_analytics.get("total_elapsed_s", 0) + total_elapsed_s,
  "avg_elapsed_s": avg_elapsed_s,
  "last_findings": {
    "security_critical": security_critical_count,
    "security_high": security_high_count,
    "tests_passing": tests_passing_count
  }
}
Write(analytics_path, json.dumps(analytics, indent=2))
```

Surface analytics in the final summary:
- If `run_count > 1`: prepend `  Pipeline run #{run_count}. Average time: {avg_elapsed_m}m.` to the summary header.
- If first run: `  First pipeline run for this project. Data recorded for future runs.`

## Pipeline Cleanup

**Immediately after printing the final summary**, write a pipeline status marker and clean up:

```bash
echo "complete" > Claude-Production-Grade-Suite/.orchestrator/pipeline-status
```

```python
TeamDelete(team_name="production-grade")
```

This shuts down all agents and frees resources. **MANDATORY** — without it, agents remain alive indefinitely.

**Known issue:** `TeamDelete` can block indefinitely if an agent is hung (GitHub #31788). If it doesn't return within ~60s, warn user and move on.

**If the user rejects at any gate:**
```bash
echo "rejected" > Claude-Production-Grade-Suite/.orchestrator/pipeline-status
```
Then run `TeamDelete`. Never leave orphaned agents.

## Context Bridging (Wave D)

| Task | Reads From | Writes To (Project Root) | Writes To (Workspace) |
|------|-----------|--------------------------|----------------------|
| T11b: Writer (ops) | T9b SRE output, `infrastructure/` | `docs/ops-guide/` | `technical-writer/` |
| T13: Assembly | All receipts, all workspace artifacts | Project root (if user approves) | `skill-maker/` (T12 staged) |

## State Management

On entering Wave D:
```python
state["current_phase"] = "SUSTAIN"
state["current_wave"] = "D"
state["phase_file_loaded"] = true
state["tasks_active"] = ["T11b", "T13"]
```

On pipeline completion:
```python
state["tasks_active"] = []
state["current_phase"] = "COMPLETE"
```

## Common Mistakes (SUSTAIN Phase)

| Mistake | Fix |
|---------|-----|
| Not calling TeamDelete after completion | ALWAYS run `TeamDelete(team_name="production-grade")` |
| T11 (docs) fully blocked on SRE | T11a (API ref) runs in Wave A. Only T11b (ops guide) needs SRE |
| Skipping pipeline dashboard reprint | Dashboard reprints at every phase transition |
| Missing effort tracking in receipts | Every receipt must include effort field |
| Not writing Production-Grade Native directive | MANDATORY — write to CLAUDE.md for cross-session persistence |
