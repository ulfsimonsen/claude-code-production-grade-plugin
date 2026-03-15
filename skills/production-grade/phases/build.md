# Wave A — Dispatcher

This phase manages Wave A: T3a/T3b (foreground code-writing) + T4a/T5a/T6a/T6b/T9a/T11a/T12 (background analysis). Up to 9 concurrent agents.

## Visual Output

Print pipeline dashboard with BUILD ● active on phase start. Then print Wave A announcement:
```
┌─ WAVE A ──────────────────────────────── 9 agents ─┐
│                                                      │
│  FOREGROUND (worktree):                              │
│  T3a  Software Engineer    {services from arch}      │
│  T3b  Frontend Engineer    {pages from BRD}          │
│                                                      │
│  BACKGROUND (analysis):                              │
│  T4a  DevOps               Dockerfiles + CI skeleton │
│  T5a  QA Engineer          test plan from BRD        │
│  T6a  Security Engineer    STRIDE threat model       │
│  T6b  Code Reviewer        conformance checklist     │
│  T9a  SRE                  SLO definitions           │
│  T11a Technical Writer     API ref draft             │
│  T12  Skill Maker          pattern analysis          │
│                                                      │
│  All agents launched. Working autonomously...        │
└──────────────────────────────────────────────────────┘
```

When foreground agents (T3a/T3b) complete, print:
```
┌─ WAVE A: BUILD COMPLETE ─────────────── ⏱ {time} ─┐
│                                                      │
│  ✓ Software Engineer    {N} services, {M} endpoints  │
│  ✓ Frontend Engineer    {N} pages, {M} components    │
│                                                      │
│  Background analysis: {N}/7 complete, {M} still running│
│  → Merging worktrees, starting Wave B                │
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
# First check if settings.md already has a Worktrees decision (e.g., from a prior run or Auto mode)
settings = Read("Claude-Production-Grade-Suite/.orchestrator/settings.md")
if "Worktrees: enabled" in settings or "Worktrees: disabled" in settings:
  use_worktrees = "Worktrees: enabled" in settings
  # Skip the question — decision already made (Auto mode always pre-sets this)
else:
  # Check for clean git state (worktrees require committed state)
  result = Bash("git status --porcelain 2>/dev/null | head -5")
  if result.strip():
    # Auto mode: auto-commit without asking
    if "Engagement: auto" in settings:
      Bash("git add -A && git commit -m 'auto: pre-Wave A checkpoint'")
      use_worktrees = True
    else:
      # Non-auto: ask user
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
      # If auto-commit: git add -A && git commit -m "production-grade: pre-Wave A checkpoint"
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

## FOREGROUND: T3a + T3b (code-writing, worktree)

Spawn backend and frontend agents simultaneously as foreground Agents.
When `use_worktrees` is True, add `isolation="worktree"` to each Agent call.

**IMPORTANT:** T3a and T3b MUST run as foreground agents (no `run_in_background`). Both Agent calls in the same message execute concurrently, but the orchestrator blocks until both return — then continues to worktree merge-back. Background agents would lose worktree changes.

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
When complete, write a receipt JSON (including completed_at timestamp) to Claude-Production-Grade-Suite/.orchestrator/receipts/T3a-software-engineer.json with task, agent, phase, status, completed_at, artifacts, metrics, effort, verification. Then mark your task as completed.""",
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
  Auto/Express: auto-select best style for the domain, report choice, proceed. Log to auto-decisions.md if Auto mode.
  Standard+: ask user via AskUserQuestion (Creative | Elegance | High Tech | Corporate | Custom).

Write frontend to project root: frontend/
Write workspace artifacts to: Claude-Production-Grade-Suite/frontend-engineer/
When complete, write a receipt JSON (including completed_at timestamp) to Claude-Production-Grade-Suite/.orchestrator/receipts/T3b-frontend-engineer.json with task, agent, phase, status, completed_at, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Remove this line if use_worktrees is False
)
```

## BACKGROUND: Analysis Agents (no worktree, workspace-only writes)

Launch these IN THE SAME MESSAGE as T3a/T3b above. They run concurrently with the foreground agents but don't block the orchestrator's execution chain when foreground agents return.

**These agents write ONLY to `Claude-Production-Grade-Suite/` workspace directories — no project root writes, no worktree needed, no merge-back required.** As of Claude Code 2.1.76, killing a background agent preserves its partial results in context.

```python
# T4a: DevOps analysis — Dockerfiles + CI skeleton from architecture
TaskUpdate(taskId=t4a_id, status="in_progress")
Agent(
  prompt="""You are the DevOps Containerization Analyst.
Read architecture from docs/architecture/ and API specs from api/.
Read .production-grade.yaml for preferences.
Write Dockerfiles (one per service) and docker-compose.yml skeleton based on architecture.
Write to Claude-Production-Grade-Suite/devops/dockerfiles/ and Claude-Production-Grade-Suite/devops/compose-draft.yml.
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T4a-devops-analysis.json.""",
  subagent_type="general-purpose",
  model="sonnet",
  run_in_background=True
)

# T5a: QA test plan from BRD + architecture
TaskUpdate(taskId=t5a_id, status="in_progress")
Agent(
  prompt="""You are the QA Test Planner.
Read BRD from Claude-Production-Grade-Suite/product-manager/BRD/brd.md.
Read architecture from docs/architecture/ and API specs from api/.
Write a comprehensive test plan covering unit, integration, contract, e2e, and performance tests.
Map each user story to specific test scenarios with expected inputs/outputs.
Write to Claude-Production-Grade-Suite/qa-engineer/test-plan.md.
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T5a-qa-plan.json.""",
  subagent_type="general-purpose",
  model="opus",  # Analysis tier — test plan requires judgment
  run_in_background=True
)

# T6a: Security STRIDE threat model from architecture
TaskUpdate(taskId=t6a_id, status="in_progress")
Agent(
  prompt="""You are the Security Threat Modeler — SOLE authority on STRIDE.
Read architecture from docs/architecture/, API specs from api/, data models from schemas/.
Perform STRIDE analysis on each service boundary and data flow.
Identify threats, rank by severity, map to OWASP Top 10 categories.
Write to Claude-Production-Grade-Suite/security-engineer/threat-model/.
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T6a-security-stride.json.""",
  subagent_type="general-purpose",
  model="opus",  # Analysis tier — threat modeling requires deep judgment
  run_in_background=True
)

# T6b: Code Reviewer conformance checklist from architecture
TaskUpdate(taskId=t6b_id, status="in_progress")
Agent(
  prompt="""You are the Code Review Planner — architecture conformance and code quality ONLY.
DO NOT perform security review — security-engineer is sole authority.
Read architecture ADRs from docs/architecture/architecture-decision-records/.
Read API contracts from api/.
Build a review checklist: SOLID/DRY/KISS patterns, naming conventions, error handling patterns,
performance anti-patterns to watch for, test quality criteria.
Write to Claude-Production-Grade-Suite/code-reviewer/checklist.md.
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T6b-review-checklist.json.""",
  subagent_type="general-purpose",
  model="opus",  # Analysis tier — checklist design requires judgment
  run_in_background=True
)

# T9a: SRE SLO definitions from architecture
TaskUpdate(taskId=t9a_id, status="in_progress")
Agent(
  prompt="""You are the SRE — SOLE authority on SLO/SLI definitions.
Read architecture from docs/architecture/ and BRD from Claude-Production-Grade-Suite/product-manager/BRD/.
Define SLIs (latency, availability, error rate) per service.
Define SLOs with targets based on BRD constraints (scale, user expectations).
Define error budgets and burn-rate alert thresholds.
Write to Claude-Production-Grade-Suite/sre/slos.md.
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T9a-sre-slos.json.""",
  subagent_type="general-purpose",
  model="opus",  # Analysis tier — SLO design requires judgment
  run_in_background=True
)

# T11a: Technical Writer API ref draft from OpenAPI specs
TaskUpdate(taskId=t11a_id, status="in_progress")
Agent(
  prompt="""You are the Technical Writer — API Reference.
Read OpenAPI specs from api/openapi/*.yaml.
Read architecture overview from docs/architecture/.
Generate API reference documentation: endpoints, request/response schemas, auth requirements, error codes.
Generate developer quick-start guide from BRD user stories.
Write to Claude-Production-Grade-Suite/technical-writer/api-reference/ and Claude-Production-Grade-Suite/technical-writer/guides/.
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T11a-techwriter-api.json.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — structured doc generation
  run_in_background=True
)

# T12: Skill Maker pattern analysis from architecture
TaskUpdate(taskId=t12_id, status="in_progress")
Agent(
  prompt="""You are the Skill Maker.
Use the Skill tool to invoke 'production-grade:skill-maker' to load your complete methodology.
Read architecture from docs/architecture/, API contracts from api/.
Read BRD from Claude-Production-Grade-Suite/product-manager/BRD/.
Analyze patterns: API routes, data models, auth flows, deployment patterns.
Generate 3-5 project-specific skills as SKILL.md files.
Stage skills to: Claude-Production-Grade-Suite/skill-maker/skills/ (sandbox blocks direct writes to .claude/skills/).
Write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T12-skill-maker.json.""",
  subagent_type="general-purpose",
  model="opus",  # Analysis tier — skill design requires deep judgment
  run_in_background=True
)
```

## Merge T3a/T3b Worktree Branches

After foreground agents (T3a/T3b) complete, merge their worktree branches back immediately. Background agents may still be running — that's OK, they write to workspace dirs only.

**How to collect worktree branch names from Agent results:**
When an Agent call uses `isolation="worktree"`, the result includes the branch name (e.g., `branch: production-grade-agent-XXXXX`). Parse and store these when processing each Agent's return.

```python
# Merge T3a/T3b worktree branches
for branch in [t3a_branch, t3b_branch]:  # collected from Agent results
  if branch:  # t3b_branch is None if frontend was skipped
    Bash(f"git merge --no-ff {branch} -m 'production-grade: merge {branch}'")
    Bash(f"git branch -d {branch}")
# Stale worktrees auto-cleaned (2.1.76+). Merge conflicts escalated to user.
```

## Completion

When foreground BUILD tasks complete and branches are merged:
1. **Verify foreground receipts:** Read `Claude-Production-Grade-Suite/.orchestrator/receipts/T3a-*.json`, `T3b-*.json`. Verify listed artifacts exist on disk.
2. **Check background status:** List background analysis receipts that have appeared. Log which are done and which are still running. Wave B readiness check will verify all required outputs before launching.
3. **Re-anchor:** Re-read from disk before transitioning to Wave B:
   - Directory listing of `services/`, `frontend/`, `libs/shared/` (what was actually built)
   - Background analysis outputs (if available): `Claude-Production-Grade-Suite/qa-engineer/test-plan.md`, `Claude-Production-Grade-Suite/security-engineer/threat-model/`, `Claude-Production-Grade-Suite/code-reviewer/checklist.md`
4. Verify all services compile and start
5. Log Wave A BUILD completion to workspace
6. Read `phases/harden.md` and begin Wave B — use freshly-read data for agent prompts

## Failure Handling

- Build failure after 3 retries → in Auto mode: log failure, mark task `completed_with_errors`, proceed. In other modes: escalate to user via AskUserQuestion.
- Frontend fails but backend succeeds → continue backend-only pipeline
- Background agent fails → Wave B readiness check detects missing output, falls back to inline analysis
- Agents self-debug: read errors, fix, retry before escalating

## Task Dependency Graph

Create tasks with TaskCreate, then set dependencies with TaskUpdate using the returned IDs.

**Wave A tasks** — all depend on T2 (architecture), no dependencies on each other:

| Task | Blocked By | Mode | Notes |
|------|-----------|------|-------|
| T3a | T2 | Foreground | Backend — spawns 1 Agent per service from architecture |
| T3b | T2 | Foreground | Frontend — spawns 1 Agent per page group from BRD |
| T4a | T2 | Background | DevOps analysis — Dockerfiles + CI skeleton |
| T5a | T2 | Background | QA test plan — from BRD + architecture |
| T6a | T2 | Background | Security threat model — STRIDE from architecture |
| T6b | T2 | Background | Review prep — arch conformance checklist |
| T9a | T2 | Background | SRE — SLO definitions from architecture |
| T11a | T2 | Background | Technical Writer — API ref draft from OpenAPI specs |
| T12 | T2 | Background | Skill Maker — pattern analysis from architecture |

### Dynamic Task Generation

After Gate 2, the orchestrator reads architecture output to determine work units:
1. **Count services** — Read `docs/architecture/` service list. For each, create a subtask under T3a.
2. **Count pages** — Read BRD user stories. Group into page clusters. For each group, create a subtask under T3b.
3. **Generate Wave A TaskList** — All T3a subtasks + T3b subtasks + background tasks.

### Conditional Tasks

- **T3b (Frontend):** Skip if `.production-grade.yaml` has `features.frontend: false`
- **T10 (Data Scientist):** Auto-detect by scanning for `openai`, `anthropic`, `langchain`, `transformers`, `torch`, `tensorflow` imports. Skip if not detected and `features.ai_ml: false`.

## Model Tier Strategy

Per-agent model selection (requires Claude Code 2.1.76+). Uses a **planner-executor pattern**: opus plans, sonnet executes.

**Principle:** Sonnet needs unambiguous instructions. Opus reasons about WHAT to build; sonnet implements exactly what opus specified.

| Role | Model | Tasks | What It Does |
|------|-------|-------|-------------|
| **Planner** | `opus` | Wave Planners | Reads architecture + BRD, writes file-level execution plans |
| **Analysis** | `opus` | T5a, T6a, T6b, T9a, T10, T12 | Judgment: threat modeling, code review, SLO design |
| **Executor** | `sonnet` | T3a, T3b, T4, T5b, T7, T8, T11 | Implements exactly what the plan specifies |

Before each parallel wave with sonnet agents, spawn a single **opus wave planner**. Plans stored at `Claude-Production-Grade-Suite/.orchestrator/plans/`.

**Key insight:** The opus analysis agents in Wave A (T5a, T6a, T6b, T9a) ARE planners — they produce outputs that sonnet agents execute against in later waves.

### Execution Plan Format

Plans must be unambiguous enough for sonnet to implement without making decisions:

```markdown
# Execution Plan: T3a Backend Engineer

## Overview
Architecture: modular monolith (ADR-001)
Language: TypeScript / Node.js / Express
Database: PostgreSQL with Prisma ORM

## services/order-service/src/handlers/create-order.ts
- Export: handleCreateOrder(req: CreateOrderRequest): Promise<OrderResponse>
- Middleware: authMiddleware, validateBody(CreateOrderSchema)
- Steps:
  1. Extract idempotencyKey from req.headers...
  [every step explicit, no "implement business logic"]
```

### Which Waves Get Planners

| Wave | Planner? | Why |
|------|----------|-----|
| Wave A | Yes | T3a, T3b, T4 need file-level plans from architecture |
| Wave B | No | T5b reads T5a plan. T4b reads T4 Dockerfiles. T6c, T6d are opus. |
| Wave C | Yes | T8 needs opus to translate findings into fix instructions |
| Wave D | No | T11 reads full workspace. T12 is opus. |

### Settings

Enabled by default. To disable: add `Model-Optimization: disabled` to settings.md. When disabled, omit `model` from Agent calls and skip wave planners.

## Workspace Architecture

```
Claude-Production-Grade-Suite/
├── .protocols/              # Shared protocols (written at bootstrap)
├── .orchestrator/           # Pipeline state, receipts, plans
│   ├── state.json           # Current pipeline state (phase, wave, tasks)
│   ├── receipts/            # Task completion receipts (validated by hooks)
│   ├── plans/               # Wave planner outputs
│   ├── settings.md          # Engagement, parallelism, worktree choices
│   └── pre-compact-snapshot.json  # PreCompact hook output
├── product-manager/         # BRD, research
├── solution-architect/      # Architecture artifacts
├── software-engineer/       # Backend logs/artifacts
├── frontend-engineer/       # Frontend logs/artifacts
├── qa-engineer/             # Test artifacts
├── security-engineer/       # Security findings
├── code-reviewer/           # Quality findings
├── devops/                  # Infrastructure artifacts
├── sre/                     # Readiness artifacts
├── data-scientist/          # AI/ML artifacts (conditional)
├── technical-writer/        # Documentation artifacts
└── skill-maker/             # Custom skills
```

## Context Bridging (Wave A)

| Task | Reads From | Writes To (Project Root) | Writes To (Workspace) |
|------|-----------|--------------------------|----------------------|
| T3a: Backend | `api/`, `schemas/`, `docs/architecture/` | `services/`, `libs/shared/` | `software-engineer/` |
| T3b: Frontend | `api/`, `product-manager/BRD/` | `frontend/` | `frontend-engineer/` |
| T4a: DevOps | `docs/architecture/` | Dockerfiles at root | `devops/` |
| T5a: QA | `product-manager/BRD/`, `api/`, `docs/architecture/` | — | `qa-engineer/test-plan.md` |
| T6a: Security | `docs/architecture/`, `api/` | — | `security-engineer/threat-model/` |
| T6b: Review | `docs/architecture/`, `api/` | — | `code-reviewer/checklist.md` |
| T9a: SRE | `docs/architecture/`, `product-manager/BRD/` | — | `sre/slos.md` |
| T11a: Writer | `api/`, `services/`, `frontend/` | — | `technical-writer/` |
| T12: Skills | Architecture, implementation | — | `skill-maker/` |

## State Management

On entering Wave A, update state:
```python
state["current_phase"] = "BUILD"
state["current_wave"] = "A"
state["phase_file_loaded"] = true
state["tasks_active"] = ["T3a", "T3b", "T4a", "T5a", "T6a", "T6b", "T9a", "T11a", "T12"]
```

On Wave A completion:
```python
state["current_wave"] = "B"
state["phase_file_loaded"] = false
state["tasks_active"] = ["T4b", "T5b", "T6c", "T6d", "T7"]
```

## Common Mistakes (BUILD Phase)

| Mistake | Fix |
|---------|-----|
| Sequential when parallel possible | Maximum parallelism: 4-wave execution. Every independent unit gets its own agent |
| Background analysis agents using worktrees | Background agents write to workspace only — no worktree, use `run_in_background=True` |
| Running parallel code-writing agents without worktree | Use `isolation="worktree"` on foreground code-writing agents |
| Not merging worktree branches after wave | Merge all foreground branches before next wave reads outputs |
| All agents running on Opus | Use model tiers: opus for planners + analysis, sonnet for executors |
| Omitting `model` when optimization enabled | Every Agent call MUST include `model` from tier table |
| Worktree agents blocked on file operations | Fall back to shared directory if permission errors (GitHub #29110) |
| Worktree cleanup deleting uncommitted work | Foreground agents MUST commit before returning |
| `✓ Analysis complete` without numbers | Every completion line MUST include concrete counts |
| Missing wave announcements | Print Tier 2 box before and after every parallel wave |
