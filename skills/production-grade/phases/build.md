# BUILD Phase — Dispatcher

This phase manages tasks T3a (Backend), T3b (Frontend), and T4 (DevOps Containerization). Features PARALLEL #1 and #2.

## Visual Output

Print pipeline dashboard with BUILD ● active on phase start. Then print Wave A announcement:
```
┌─ BUILD ──────────────────────────────── {N} agents ─┐
│                                                      │
│  T3a  Software Engineer    {services from arch}      │
│  T3b  Frontend Engineer    {pages from BRD}          │
│                                                      │
│  Agents launched. Working autonomously...            │
└──────────────────────────────────────────────────────┘
```

When Wave A completes, print the checkmark cascade:
```
┌─ BUILD COMPLETE ──────────────────────── ⏱ {time} ─┐
│                                                      │
│  ✓ Software Engineer    {N} services, {M} endpoints  │
│  ✓ Frontend Engineer    {N} pages, {M} components    │
│  ✓ DevOps               {N} Dockerfiles, 1 compose   │
│                                                      │
│  {N}/{N} complete                                    │
│  → Starting HARDEN phase                             │
└──────────────────────────────────────────────────────┘
```

Each agent's completion line MUST include concrete numbers.

## Re-Anchor

Before creating any agent tasks, re-read key artifacts from disk:
- `Claude-Production-Grade-Suite/product-manager/BRD/brd.md`
- `Claude-Production-Grade-Suite/solution-architect/` workspace artifacts (working-notes.md, analysis/*.md)
- `docs/architecture/architecture-decision-records/*.md` (Glob to list, Read key ADRs)
- `api/openapi/*.yaml` (Glob to list)
- `Claude-Production-Grade-Suite/.orchestrator/receipts/T1-*.json`, `Claude-Production-Grade-Suite/.orchestrator/receipts/T2-*.json`

Use this freshly-read data when writing agent task prompts below — not your compressed memory of DEFINE phase.

## Pre-Flight

Read `.production-grade.yaml` to determine:
- `features.frontend` → if false, skip T3b
- `project.architecture` → monolith vs microservices (affects containerization)
- `paths.services`, `paths.frontend`, `paths.shared_libs` → output locations

## Worktree Pre-Flight

Before launching parallel agents, check if a worktree decision already exists in settings:

```python
# First check if settings.md already has a Worktrees decision (e.g., from a prior run)
settings = Read("Claude-Production-Grade-Suite/.orchestrator/settings.md")
if "Worktrees: enabled" in settings or "Worktrees: disabled" in settings:
  use_worktrees = "Worktrees: enabled" in settings
  # Skip the question — decision already made
else:
  # Check for clean git state (worktrees require committed state)
  result = Bash("git status --porcelain 2>/dev/null | head -5")
  if result.strip():
    # Dirty repo — ask user
    AskUserQuestion(questions=[{
      "question": "Parallel agents work best with worktree isolation, but you have uncommitted changes.",
      "header": "Worktree Isolation",
      "options": [
        {"label": "Auto-commit and use worktrees (Recommended)", "description": "Commit current state, isolate each agent in its own worktree"},
        {"label": "Skip worktrees — run in shared directory", "description": "Agents share the working directory (risk of file conflicts)"},
        {"label": "Chat about this", "description": "Free-form input"}
      ],
      "multiSelect": false
    }])
    # If auto-commit: git add -A && git commit -m "production-grade: pre-BUILD checkpoint"
    # If skip: set use_worktrees = False
  else:
    use_worktrees = True
```

Store the worktree decision in `Claude-Production-Grade-Suite/.orchestrator/settings.md` by appending:
```
Worktrees: [enabled|disabled]
```

## Wave A Planning (opus planner)

Before dispatching parallel agents, spawn a single opus planner that reads all architecture artifacts and writes file-level execution plans for the sonnet agents. Skip this step if `Model-Optimization: disabled` in settings.

```python
# Wave A Planner — opus reasons about WHAT to build; sonnet agents implement
Agent(
  prompt="""You are the Wave A Planner. Your job: read architecture artifacts and produce detailed, unambiguous execution plans for the BUILD agents.

Read these inputs:
- Claude-Production-Grade-Suite/product-manager/BRD/brd.md (user stories, acceptance criteria)
- Claude-Production-Grade-Suite/solution-architect/ workspace artifacts (architecture pattern, service boundaries)
- docs/architecture/architecture-decision-records/*.md (all architecture decisions)
- api/openapi/*.yaml (all API contracts)
- schemas/ (data models)
- .production-grade.yaml (path overrides, framework preferences)

Write these plan files to Claude-Production-Grade-Suite/.orchestrator/plans/wave-a/:

1. **T3a-backend-plan.md** — For each service in the architecture:
   - Every file to create (full path)
   - Every exported function/class with signature
   - Implementation steps for each function (numbered, specific)
   - Error handling per function (which errors, what response)
   - Dependencies between services (which clients to call, what events to emit)
   - Database operations (exact Prisma/SQL calls, not "persist data")
   - Middleware chain per route

2. **T3b-frontend-plan.md** — For each page group from BRD:
   - Every component to create (path, props interface)
   - Page layout structure (which components, where)
   - API client calls per page (which endpoints, what state)
   - Route definitions (path, auth requirements, layout)
   - Form validations (which fields, what rules)
   - Navigation wiring (every link, button, redirect)

3. **T4-containers-plan.md** — For each service:
   - Base image and version
   - Build stages (dependencies, build, runtime)
   - Exposed ports, health check path
   - Environment variables needed
   - docker-compose service entry

Plans must be detailed enough that an agent can implement WITHOUT making architectural decisions. Every function gets explicit steps. No "implement business logic" — specify the logic.""",
  subagent_type="general-purpose",
  model="opus"  # Planner tier — always opus
)
```

## PARALLEL #1: T3a + T3b

Spawn backend and frontend agents simultaneously as foreground Agents.
When `use_worktrees` is True, add `isolation="worktree"` to each Agent call. Each agent gets its own isolated copy of the repo — no file race conditions.

**IMPORTANT:** T3a and T3b MUST run as foreground agents (no `run_in_background`). Both Agent calls in the same message still execute concurrently, but the orchestrator blocks until both return — then naturally continues to worktree merge-back and T4. Using background agents here causes the orchestrator turn to end before merge-back can fire, losing worktree changes.

```python
# T3a: Backend Engineering — executes Wave A plan
TaskUpdate(taskId=t3a_id, status="in_progress")
Agent(
  prompt="""You are the Backend Engineer.
Read your execution plan: Claude-Production-Grade-Suite/.orchestrator/plans/wave-a/T3a-backend-plan.md
Implement EXACTLY what the plan specifies — file structure, function signatures, implementation steps, error handling.
Do not deviate from the plan. Do not make architectural decisions. The plan is your specification.

Use the Skill tool to invoke 'production-grade:software-engineer' for coding methodology (patterns, testing conventions, error handling style).
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Read .production-grade.yaml for paths and preferences.
Write services to project root: services/, libs/shared/
Write workspace artifacts to: Claude-Production-Grade-Suite/software-engineer/
TDD enforced: write test → watch fail → implement → watch pass → refactor.
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T3a-software-engineer.json with task, agent, phase, status, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Remove this line if use_worktrees is False
)

# T3b: Frontend Engineering — executes Wave A plan (skip if features.frontend is false)
TaskUpdate(taskId=t3b_id, status="in_progress")
Agent(
  prompt="""You are the Frontend Engineer.
Read your execution plan: Claude-Production-Grade-Suite/.orchestrator/plans/wave-a/T3b-frontend-plan.md
Implement EXACTLY what the plan specifies — components, pages, routes, API wiring, navigation.
Do not deviate from the plan. Do not make architectural decisions. The plan is your specification.

Use the Skill tool to invoke 'production-grade:frontend-engineer' for coding methodology (6-phase build process).
Read API contracts from: api/
Read BRD user stories from: Claude-Production-Grade-Suite/product-manager/BRD/
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Read .production-grade.yaml for framework and styling preferences.

The SKILL.md gives you methodology (HOW to build). The plan gives you specification (WHAT to build).
For Phase 5 (Design & Polish), the plan may include style guidance — follow it. If the plan doesn't specify a style:
  Express: auto-select best style for the domain, report choice, proceed.
  Standard+: ask user via AskUserQuestion (Creative | Elegance | High Tech | Corporate | Custom).

Write frontend to project root: frontend/
Write workspace artifacts to: Claude-Production-Grade-Suite/frontend-engineer/
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T3b-frontend-engineer.json with task, agent, phase, status, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Remove this line if use_worktrees is False
)
```

## Merge T3a/T3b Worktree Branches Before T4

If worktrees were used for PARALLEL #1, merge T3a and T3b branches back **before** launching T4, so T4 sees the committed code:

```python
# Merge T3a/T3b worktree branches — T4 needs their output
for branch in [t3a_branch, t3b_branch]:  # collected from Agent results (see note below)
  if branch:  # t3b_branch is None if frontend was skipped
    Bash(f"git merge --no-ff {branch} -m 'production-grade: merge {branch}'")
    Bash(f"git branch -d {branch}")
# If merge conflicts: git merge --abort, escalate to user via AskUserQuestion
```

## PARALLEL #2: T4 After T3a + T3b Complete

T4 begins containerization after PARALLEL #1 completes and its branches are merged:

**IMPORTANT:** T4 MUST run as a foreground agent (no `run_in_background`). The orchestrator blocks until T4 returns — then naturally continues to worktree merge-back. Using a background agent here causes the orchestrator turn to end before merge-back can fire, losing worktree changes.

```python
TaskUpdate(taskId=t4_id, status="in_progress")
Agent(
  prompt="""You are the DevOps Containerization Engineer.
Read your execution plan: Claude-Production-Grade-Suite/.orchestrator/plans/wave-a/T4-containers-plan.md
If the plan file does not exist (Model-Optimization disabled), read architecture from
docs/architecture/ and service structure from services/ to determine containerization needs.
Implement base images, build stages, ports, health checks, compose entries.
If a plan exists, follow it EXACTLY — do not deviate or make infrastructure decisions.

Use the Skill tool to invoke 'production-grade:devops' to load your complete methodology and follow it.
Read services from: services/
Read .production-grade.yaml for paths and preferences.
Write Dockerfiles per service, docker-compose.yml at project root.
Write workspace artifacts to: Claude-Production-Grade-Suite/devops/
Validate: docker build succeeds for each service, docker-compose up starts all.
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T4-devops.json with task, agent, phase, status, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Remove this line if use_worktrees is False
)
```

## Worktree Merge-Back

If worktrees were used, merge each agent's branch back to the working branch after the wave completes:

**How to collect worktree branch names from Agent results:**

When an Agent call uses `isolation="worktree"`, the Agent tool's return value includes the worktree branch name in the result text. Parse the result for the branch name — it appears in the format: `worktree path: /path/to/worktree` and `branch: production-grade-agent-XXXXX`. Store these when processing each Agent's return.

```python
# T4 worktree merge (T3a/T3b branches were already merged above before T4 launched)
if t4_branch:
  Bash(f"git merge --no-ff {t4_branch} -m 'production-grade: merge {t4_branch}'")
  Bash(f"git branch -d {t4_branch}")

# If any merge has conflicts:
#   1. Run: git merge --abort
#   2. Escalate to user via AskUserQuestion
#   3. Offer: "Resolve conflicts manually" or "Retry without worktrees"
```

After merging, all agent outputs are unified in the working directory.

## Completion

When all BUILD tasks complete:
1. **Merge worktree branches** (if worktrees enabled) — see Worktree Merge-Back above.
2. **Verify receipts:** Read all BUILD receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/` (T3a, T3b, T4). Verify all listed artifacts exist on disk.
3. **Re-anchor:** Re-read from disk before transitioning to HARDEN:
   - Directory listing of `services/`, `frontend/`, `libs/shared/` (what was actually built)
   - `Claude-Production-Grade-Suite/solution-architect/` workspace artifacts (architecture reference for HARDEN agents)
4. Verify all services compile and start
5. Verify docker-compose brings up the full stack
6. Log BUILD completion to workspace
7. Read `phases/harden.md` and begin HARDEN phase — use freshly-read data for agent prompts

## Failure Handling

- Build failure after 3 retries → escalate to user via AskUserQuestion
- Frontend fails but backend succeeds → continue backend-only pipeline
- Agents self-debug: read errors, fix, retry before escalating
