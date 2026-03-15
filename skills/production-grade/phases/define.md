# DEFINE Phase — Dispatcher

This phase manages tasks T1 (Product Manager) and T2 (Solution Architect). Sequential execution with Gate 1 and Gate 2.

## Visual Output

Print pipeline dashboard with DEFINE ● active on phase start:
```
  → Starting DEFINE phase
```

Each skill (PM, Architect) prints its own `━━━ [Skill Name] ━━━` header and `[1/N]` phase progress per visual-identity protocol.

Print gate ceremony before each gate (see orchestrator Gate 1 and Gate 2 templates).

On phase completion, print transition:
```
  → DEFINE complete, starting BUILD phase
```

## Pre-Flight

Read `.production-grade.yaml` for path overrides:
- `paths.brd` → BRD output location (default: `Claude-Production-Grade-Suite/product-manager/BRD/`)
- `paths.api_contracts` → API contract location (default: `api/openapi/*.yaml`)
- `paths.adrs` → ADR location (default: `docs/architecture/architecture-decision-records/`)
- `paths.architecture_docs` → Architecture docs (default: `docs/architecture/`)

## T1: Product Manager — BRD

### Auto Mode Behavior

If `Engagement: auto` in `Claude-Production-Grade-Suite/.orchestrator/settings.md`:

**Do NOT invoke the product-manager Skill** (it will try to conduct an interview). Instead, spawn an Agent that auto-derives the BRD:

```python
TaskUpdate(taskId=t1_id, status="in_progress")
Agent(
  prompt="""You are the Product Manager operating in AUTO MODE — zero user interaction.
Read the user's original request from the conversation context. DO NOT use AskUserQuestion. DO NOT ask any questions.

Auto-derive the BRD entirely from:
1. The user's request description (extract project goals, features, constraints)
2. WebSearch for domain knowledge (market context, competitor patterns, common requirements)
3. Reasonable defaults for anything not specified (pick the most common/sensible option)

Write a complete BRD to Claude-Production-Grade-Suite/product-manager/BRD/:
- brd.md: Full BRD with user stories, acceptance criteria, stakeholder analysis, constraints
- INDEX.md: Table of contents

For every decision you make autonomously, log it:
Write to Claude-Production-Grade-Suite/.orchestrator/auto-decisions.md (append):
  - "[T1] {decision} — {reasoning}"

Quality bar: minimum 5 user stories with acceptance criteria each. No placeholders, no TODOs.
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json.""",
  subagent_type="general-purpose",
  model="opus"  # PM requires judgment
)
TaskUpdate(taskId=t1_id, status="completed")
```

### Standard Mode Behavior (non-Auto)

Mark task in progress and invoke as Skill (needs user interaction for CEO interview):

```python
TaskUpdate(taskId=t1_id, status="in_progress")
Skill(skill="production-grade:product-manager")
```

The product-manager skill will:
1. Research domain via WebSearch
2. Conduct CEO interview (3-5 questions via AskUserQuestion with multiSelect)
3. Write BRD to `Claude-Production-Grade-Suite/product-manager/BRD/`
4. Outputs: `brd.md`, `INDEX.md`

**On completion:** The product-manager writes a receipt to `Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json`, then:
```python
TaskUpdate(taskId=t1_id, status="completed")
```

### Gate 1 — BRD Approval

**Before opening gate:** Read `Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json`. Verify all `artifacts` exist on disk. Use receipt `metrics` for gate display numbers.

#### Auto Mode — Gate 1 Auto-Approve

If `Engagement: auto` in settings.md:

1. Verify receipt exists and all artifacts are on disk
2. Print the gate ceremony with `[AUTO-APPROVED]`:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⬥ GATE 1 — Requirements Approval  [AUTO-APPROVED]  ⏱ {elapsed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  User Stories       {N} with acceptance criteria
  Stakeholders       {N} roles identified
  Constraints        {key constraints summary}
  Scope              {brief scope summary}

  ✓ Auto-approved — receipts verified, artifacts exist
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
3. Do NOT call AskUserQuestion. Proceed directly to T2.
4. If receipt verification fails (missing artifacts), log the failure and proceed anyway:
   `⚠ Auto: Gate 1 receipt verification incomplete — proceeding with best effort`

#### Standard Mode — Gate 1 (non-Auto)

**Gate 1 Visual Ceremony:**

Print the pipeline dashboard (DEFINE ● active), then:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⬥ GATE 1 — Requirements Approval                  ⏱ {elapsed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  User Stories       {N} with acceptance criteria
  Stakeholders       {N} roles identified
  Constraints        {key constraints summary}
  Scope              {brief scope summary}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then ask:
```python
AskUserQuestion(questions=[{
  "question": "BRD complete: [X] user stories, [Y] acceptance criteria. Approve?",
  "header": "Gate 1: Requirements",
  "options": [
    {"label": "Approve — start architecture (Recommended)", "description": "BRD locked, proceed to Solution Architect"},
    {"label": "Show BRD details", "description": "Display the full BRD before deciding"},
    {"label": "I have changes", "description": "Request modifications to requirements"},
    {"label": "Chat about this", "description": "Free-form input about the BRD"}
  ],
  "multiSelect": false
}])
```

When the user selects "Chat about this", invoke the polymath in translate mode:
```python
Skill(skill="production-grade:polymath")
```
The polymath reads gate artifacts, explains in plain language, then re-presents gate options.

On approval, unblock T2.

If user selects "I have changes" → iterate on BRD, re-present Gate 1.
If user selects "Show BRD details" → display BRD, re-present Gate 1.

## T2: Solution Architect — Architecture

### Auto Mode Behavior

If `Engagement: auto` in `Claude-Production-Grade-Suite/.orchestrator/settings.md`:

**Do NOT invoke the solution-architect Skill** (it will try to conduct a discovery interview). Instead, spawn an Agent that auto-derives the architecture:

```python
TaskUpdate(taskId=t2_id, status="in_progress")
Agent(
  prompt="""You are the Solution Architect operating in AUTO MODE — zero user interaction.
Read the BRD from Claude-Production-Grade-Suite/product-manager/BRD/brd.md. DO NOT use AskUserQuestion. DO NOT ask any questions.

Auto-derive the complete architecture from the BRD:
1. Infer the best architecture pattern (monolith, modular monolith, microservices) from project scale
2. Select tech stack based on BRD constraints and domain (use WebSearch for current best practices)
3. Design service boundaries from user stories
4. Design API contracts (OpenAPI 3.1) from acceptance criteria
5. Design data model and migrations from domain entities
6. Write ADRs for every significant decision (minimum 3)
7. Generate project scaffold (directory structure, package files, config)

Write deliverables to project root: api/, schemas/, docs/architecture/
Write workspace artifacts to: Claude-Production-Grade-Suite/solution-architect/

For every decision you make autonomously, log it:
Write to Claude-Production-Grade-Suite/.orchestrator/auto-decisions.md (append):
  - "[T2] {decision} — {reasoning}"

Quality bar: minimum 3 ADRs, complete OpenAPI specs, data model with migrations. No placeholders, no TODOs.
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T2-solution-architect.json.""",
  subagent_type="general-purpose",
  model="opus"  # Architecture requires deep judgment
)
TaskUpdate(taskId=t2_id, status="completed")
```

### Standard Mode Behavior (non-Auto)

```python
TaskUpdate(taskId=t2_id, status="in_progress")
Skill(skill="production-grade:solution-architect")
```

The solution-architect skill will:
1. Read BRD from `Claude-Production-Grade-Suite/product-manager/BRD/`
2. Design architecture: ADRs, tech stack, system design
3. Design API contracts (OpenAPI 3.1), data model (ERD), migrations
4. Generate project scaffold
5. Write deliverables to **project root**: `api/`, `schemas/`, `docs/architecture/`
6. Write workspace artifacts to `Claude-Production-Grade-Suite/solution-architect/`

**On completion:** The solution-architect writes a receipt to `Claude-Production-Grade-Suite/.orchestrator/receipts/T2-solution-architect.json`, then:
```python
TaskUpdate(taskId=t2_id, status="completed")
```

### Gate 2 — Architecture Approval

**Before opening gate:** Read `Claude-Production-Grade-Suite/.orchestrator/receipts/T2-solution-architect.json`. Verify all `artifacts` exist on disk. Use receipt `metrics` for gate display numbers.

#### Auto Mode — Gate 2 Auto-Approve

If `Engagement: auto` in settings.md:

1. Verify receipt exists and all artifacts are on disk
2. Print the gate ceremony with `[AUTO-APPROVED]`:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⬥ GATE 2 — Architecture Approval  [AUTO-APPROVED]  ⏱ {elapsed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Pattern      {architecture pattern}
  Stack        {language} · {framework} · {database} · {cache}
  Services     {N} bounded contexts
  API          {N} endpoints across {M} specs
  ADRs         {N} architecture decision records
  Data         {N} entities, {M} migrations

  ✓ Auto-approved — receipts verified, artifacts exist
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
3. Do NOT call AskUserQuestion. Proceed directly to BUILD phase.
4. If receipt verification fails (missing artifacts), log the failure and proceed anyway:
   `⚠ Auto: Gate 2 receipt verification incomplete — proceeding with best effort`

#### Standard Mode — Gate 2 (non-Auto)

**Gate 2 Visual Ceremony:**

Print the pipeline dashboard (DEFINE ✓ complete), then:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⬥ GATE 2 — Architecture Approval                  ⏱ {elapsed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Pattern      {architecture pattern}
  Stack        {language} · {framework} · {database} · {cache}
  Services     {N} bounded contexts
  API          {N} endpoints across {M} specs
  ADRs         {N} architecture decision records
  Data         {N} entities, {M} migrations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then ask:
```python
AskUserQuestion(questions=[{
  "question": "Architecture complete: [tech stack summary]. Approve to start building?",
  "header": "Gate 2: Architecture",
  "options": [
    {"label": "Approve — start building (Recommended)", "description": "Architecture locked, begin autonomous BUILD phase"},
    {"label": "Show architecture details", "description": "Walk through ADRs, diagrams, and API spec"},
    {"label": "Rework architecture", "description": "Send concerns back to Architect for revision"},
    {"label": "Chat about this", "description": "Free-form input about the architecture"}
  ],
  "multiSelect": false
}])
```

**Rework loop (Gate 2):**

If user selects "Rework architecture":
1. Ask what concerns they have (AskUserQuestion with common architecture concerns + free-form)
2. Track rework cycle: read `Claude-Production-Grade-Suite/.orchestrator/rework-log.md`, increment Gate 2 rework count
3. If rework count < 2: Re-invoke Solution Architect with the user's concerns as additional constraints.
4. If rework count >= 2: Escalate — "Architecture has been revised twice. Approve current state or discuss further?"
5. After rework: re-verify receipts, re-present Gate 2

Print rework indicator: `⬥ GATE 2 — Architecture Approval (Rework {N}/2)  ⏱ {elapsed}`

Write each rework cycle to `Claude-Production-Grade-Suite/.orchestrator/rework-log.md`:
```markdown
## Gate 2 — Rework {N}
Concerns: {user's feedback}
Changes: {what the architect modified}
```

On approval, proceed to BUILD phase.

## Handoff to BUILD

After Gate 2 approval (or auto-approval):
1. **Verify receipts:** Read `Claude-Production-Grade-Suite/.orchestrator/receipts/T1-product-manager.json` and `T2-solution-architect.json`. Verify all listed artifacts exist on disk.
2. **Re-anchor:** Re-read from disk before transitioning:
   - `Claude-Production-Grade-Suite/product-manager/BRD/brd.md`
   - `Claude-Production-Grade-Suite/solution-architect/` workspace artifacts (working-notes.md, analysis/*.md)
   - `docs/architecture/architecture-decision-records/*.md` (list files)
   - `api/openapi/*.yaml` (list files)
   - `Claude-Production-Grade-Suite/.orchestrator/settings.md`
3. Verify architecture outputs exist at project root (`api/`, `schemas/`, `docs/architecture/`)
4. Log decisions to `Claude-Production-Grade-Suite/.orchestrator/decisions-log.md`
5. Read `phases/build.md` and begin BUILD phase — use freshly-read artifacts when creating agent task prompts

## Failure Handling

- If PM cannot gather enough requirements → in Auto mode: proceed with best effort and log. In other modes: escalate to user.
- If Architect finds contradictions in BRD → in Auto mode: resolve with best judgment and log decision. In other modes: flag to user, do not silently resolve.
- Each skill self-debugs before escalating

## State Management

When entering DEFINE phase, initialize state tracking:
```python
Write("Claude-Production-Grade-Suite/.orchestrator/state.json", json.dumps({
  "pipeline_id": str(uuid4()),
  "current_phase": "DEFINE",
  "current_wave": null,
  "phase_file_loaded": true,
  "gates_passed": [],
  "tasks_completed": [],
  "tasks_active": ["T1"],
  "last_transition": datetime.utcnow().isoformat() + "Z"
}))
```

After Gate 1 approval, update state:
```python
# Update state.json
state["gates_passed"].append("G1")
state["tasks_completed"].append("T1")
state["tasks_active"] = ["T2"]
```

After Gate 2 approval:
```python
state["gates_passed"].append("G2")
state["tasks_completed"].append("T2")
state["current_phase"] = "BUILD"
state["current_wave"] = "A"
state["phase_file_loaded"] = false
state["tasks_active"] = ["T3a", "T3b", "T4a", "T5a", "T6a", "T6b", "T9a", "T11a", "T12"]
```

## Common Mistakes (DEFINE Phase)

| Mistake | Fix |
|---------|-----|
| Running BUILD without DEFINE | Architecture decisions must exist first |
| Opening gate without verifying receipts | Read receipts and verify artifacts exist BEFORE presenting any gate |
| PM skipping interview in Express mode | Express still asks 2-3 questions minimum. Auto asks zero (auto-derives). |
| Architect ignoring engagement mode | Auto/Express auto-derives, Standard asks 5-7 questions, Thorough 12-15 |
| Over-asking the user | Respect engagement mode depth. Auto mode = zero questions. |
| Gate rejection stopping pipeline | Gates are self-healing — rework loop, max 2 cycles. Auto mode = no rejections possible. |
| Not tracking rework cycles | Log to `.orchestrator/rework-log.md` |
| Calling AskUserQuestion in Auto mode | Auto mode NEVER calls AskUserQuestion. Check settings.md first. |
| Invoking PM/Architect Skills in Auto mode | Use Agent with auto-derive prompt, NOT Skill (Skills try to interview) |
