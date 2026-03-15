# Wave C — Dispatcher

This phase manages Wave C: T8 (Remediation), T9b (SRE execution), T10 (Data Scientist). Also includes re-verification after remediation and Gate 3.

## Visual Output

Print pipeline dashboard with SHIP ● active on phase start:
```
  → Starting Wave C (remediation + SRE + data scientist)
```

## Authority Boundaries

- **sre** owns SLO execution, error budgets, runbooks, chaos engineering — does NOT provision infrastructure
- **devops** owns infrastructure provisioning — already completed in Wave B (T7)
- See `Claude-Production-Grade-Suite/.protocols/conflict-resolution.md`

## Re-Anchor

Before creating Wave C agent tasks, re-read key artifacts from disk:
- `Claude-Production-Grade-Suite/security-engineer/` findings (code-audit/, auth-review/)
- `Claude-Production-Grade-Suite/code-reviewer/` findings
- `Claude-Production-Grade-Suite/qa-engineer/` test results
- `Claude-Production-Grade-Suite/sre/slos.md` (written by T9a in Wave A background)
- `infrastructure/` listing (what T7 created)
- All Wave B receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/`

Use this freshly-read data when writing agent task prompts below.

## Wave C Planning (opus planner)

Before dispatching Wave C, spawn a single opus planner for T8 remediation. Skip if `Model-Optimization: disabled` or if no Critical/High findings exist.

```python
# Only if Critical/High findings exist from Wave B
Agent(
  prompt="""You are the Wave C Planner. Read HARDEN findings and write a remediation plan.

Read these inputs:
- Claude-Production-Grade-Suite/security-engineer/ (all security findings)
- Claude-Production-Grade-Suite/code-reviewer/ (all review findings)
- Claude-Production-Grade-Suite/qa-engineer/ (test results, failure reports)

Write plan to Claude-Production-Grade-Suite/.orchestrator/plans/ship/T8-remediation-plan.md:
For each Critical and High finding:
  - Finding ID, severity, affected file (full path), affected line range
  - Root cause analysis (what's wrong and why)
  - Exact fix instructions (what to change, not "fix the vulnerability")
  - Verification steps (which tests to run, what to re-scan)
  - Dependency order (if fix A must happen before fix B)
  - Medium/Low findings: list but mark as "document only, do not block"

Plans must be detailed enough that an agent can fix WITHOUT making severity judgments.""",
  subagent_type="general-purpose",
  model="opus"  # Planner tier — always opus
)
```

## FOREGROUND: T8 + T9b + T10

Read `Claude-Production-Grade-Suite/.orchestrator/settings.md` to check if `Worktrees: enabled`.

**IMPORTANT:** All agents MUST run as foreground agents. All Agent calls in the same message execute concurrently.

```python
# T8: Remediation — fix Critical/High findings (skip if no findings)
# If Wave B found zero Critical/High findings:
#   TaskUpdate(taskId=t8_id, status="completed")  # Skip — nothing to remediate
# If Wave B found Critical/High findings:
TaskUpdate(taskId=t8_id, status="in_progress")
Agent(
  prompt="""You are the Remediation Engineer.
Read your execution plan: Claude-Production-Grade-Suite/.orchestrator/plans/ship/T8-remediation-plan.md
Follow the plan EXACTLY — fix each finding in the specified order, using the exact fix instructions.
Do not make severity judgments. Do not skip findings the plan marks as Critical/High.

For each finding:
  1. Read the affected file at the path specified
  2. Apply the fix exactly as described
  3. Run the verification steps specified in the plan
  4. Re-scan the affected code
If findings persist after 2 fix-rescan cycles → document and escalate.
Medium/Low findings: document but do not block.
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T8-remediation.json.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T9b: SRE execution — chaos, capacity, readiness (needs T7 infra + T9a SLOs)
TaskUpdate(taskId=t9b_id, status="in_progress")
Agent(
  prompt="""You are the SRE — SOLE authority on chaos engineering, capacity planning, runbooks.
Use the Skill tool to invoke 'production-grade:sre' to load your complete methodology.
Read your SLO definitions: Claude-Production-Grade-Suite/sre/slos.md (written by T9a).
Read infrastructure from: infrastructure/, .github/workflows/ (written by T7).
Read all prior outputs: architecture, implementation, test results.
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Perform production readiness review (checklist).
Design chaos engineering scenarios and game-day playbook.
Write runbooks to project root: docs/runbooks/
Write workspace artifacts to: Claude-Production-Grade-Suite/sre/chaos/, Claude-Production-Grade-Suite/sre/capacity/
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T9b-sre-execution.json.""",
  subagent_type="general-purpose",
  model="opus",  # Deep analysis tier
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T10: Data Scientist (conditional — auto-detect LLM/ML usage)
# Before launching T10, run: Grep(pattern="(openai|anthropic|langchain|transformers|torch|tensorflow)",
#   glob="*.{py,ts,js,go,rs}", output_mode="count", head_limit=1)
# If matches > 0 OR features.ai_ml is true → launch T10:
# If no matches AND features.ai_ml is not true → skip: TaskUpdate(taskId=t10_id, status="completed")
TaskUpdate(taskId=t10_id, status="in_progress")
Agent(
  prompt="""You are the Data Scientist.
Use the Skill tool to invoke 'production-grade:data-scientist' to load your methodology.
Read implementation for LLM/ML usage patterns (imports, API calls, prompts) from services/.
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Optimize: prompt engineering, token usage, semantic caching, fallback chains.
Design: A/B testing infrastructure, experiment framework, data pipeline.
Write workspace artifacts to: Claude-Production-Grade-Suite/data-scientist/
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T10-data-scientist.json.""",
  subagent_type="general-purpose",
  model="opus",  # Deep analysis tier
  isolation="worktree"  # Omit if Worktrees: disabled
)
# If NOT detected AND features.ai_ml is false:
#   TaskUpdate(taskId=t10_id, status="completed")  # Skip
```

## Worktree Merge-Back

After Wave C agents complete, merge their worktree branches:

```python
for branch in wave_c_worktree_branches:  # [t8, t9b, t10]
  if branch:  # t10 branch is None if skipped
    Bash(f"git merge --no-ff {branch} -m 'production-grade: merge {branch}'")
    Bash(f"git branch -d {branch}")
# Stale worktrees auto-cleaned (2.1.76+). Merge conflicts escalated to user.
```

## Re-Verification After Remediation

After T8 completes and worktrees are merged, re-scan affected files:

```python
# Only runs if T8 remediated Critical/High findings
t8_receipt = Read("Claude-Production-Grade-Suite/.orchestrator/receipts/T8-remediation.json")

Agent(
  prompt="""You are the Remediation Verifier.
Read the T8 remediation receipt: Claude-Production-Grade-Suite/.orchestrator/receipts/T8-remediation.json
For each file listed in the receipt's artifacts:
  1. Read the file
  2. Check that each Critical/High finding from the original Wave B reports is resolved
  3. Re-run relevant security checks and code quality checks
  4. For each finding: mark as VERIFIED (fixed) or UNRESOLVED (still present)

Read original findings from:
- Claude-Production-Grade-Suite/security-engineer/ (code-audit/, auth-review/)
- Claude-Production-Grade-Suite/code-reviewer/

Write verification receipt (including completed_at) to:
Claude-Production-Grade-Suite/.orchestrator/receipts/T8-verification.json

If any Critical finding is UNRESOLVED after remediation, flag it clearly.""",
  subagent_type="general-purpose",
  model="opus"  # Verification requires judgment
)
```

## Receipt Verification Before Gate 3

After verification completes:
1. **Verify all receipts:** Read T8-remediation.json, T8-verification.json, T9b-sre-execution.json, T10-data-scientist.json (if applicable). Verify all listed artifacts exist.
2. **Verify remediation chain:** For each Critical/High finding from Wave B, check that T8-verification.json marks it as VERIFIED.
3. **Aggregate metrics** from all receipts for Gate 3 display — use verified receipt data and `completed_at` timestamps, not memory.

## Gate 3 — Production Readiness

Print the pipeline dashboard (DEFINE ✓, BUILD ✓, HARDEN ✓, SHIP ✓ complete), then:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⬥ GATE 3 — Production Readiness                   ⏱ {elapsed}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Services     {N} built, all compiling
  Tests        {N} passing, {M} coverage
  Security     {N} findings → {M} Critical, {K} High remaining
  Infra        {N} Dockerfiles, {M} Terraform modules
  CI/CD        {N} workflows configured
  SRE          {N} SLOs, {M} alerts, {K} runbooks

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Receipt verification before gate:**
Read ALL receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/`. For each:
- Verify `artifacts` exist on disk
- Extract `metrics` for the gate display
- For Critical/High findings: verify the remediation chain is complete
- If any receipt missing, artifact missing, or Critical finding lacks verification → flag before opening gate

Then ask:
```python
AskUserQuestion(questions=[{
  "question": "All phases complete. [summary]. Ship it?",
  "header": "Gate 3: Production Readiness",
  "options": [
    {"label": "Ship it — production ready (Recommended)", "description": "Finalize assembly and deploy"},
    {"label": "Show full report", "description": "Display complete pipeline summary"},
    {"label": "Rework — fix issues first", "description": "Run remediation cycle, then re-verify"},
    {"label": "Chat about this", "description": "Free-form input about production readiness"}
  ],
  "multiSelect": false
}])
```

**Rework loop (Gate 3):**

If user selects "Rework — fix issues first":
1. Track rework cycle in `Claude-Production-Grade-Suite/.orchestrator/rework-log.md`
2. If rework count < 2: Create remediation task, re-run verification, re-present Gate 3
3. If rework count >= 2: Escalate — "Pipeline has been through 2 remediation cycles. Ship with known issues or discuss further?"
4. Show rework indicator: `⬥ GATE 3 — Production Readiness (Rework {N}/2)`

On approval → update state and read `phases/sustain.md`.
On "Fix issues first" → rework loop.

## Wave C Task Dependencies

| Task | Blocked By | Notes |
|------|-----------|-------|
| T8 | T5b, T6c, T6d | Remediation — needs HARDEN findings |
| T9b | T7, T9a | SRE execution — needs infra + SLO defs (NOT remediation) |
| T10 | T3a | Data Scientist — conditional on AI/ML (needs code only) |

## Context Bridging (Wave C)

| Task | Reads From | Writes To (Project Root) | Writes To (Workspace) |
|------|-----------|--------------------------|----------------------|
| T8: Remediation | Wave B findings (T5b, T6c, T6d) | Fixes in `services/`, `frontend/` | — |
| T9b: SRE | T7 infra, T9a SLOs, test results | `docs/runbooks/` | `sre/chaos/`, `sre/capacity/` |
| T10: Data Sci | Implementation code (LLM usage) | — | `data-scientist/` |

## State Management

On entering Wave C:
```python
state["current_phase"] = "SHIP"
state["current_wave"] = "C"
state["phase_file_loaded"] = true
state["tasks_active"] = ["T8", "T9b", "T10"]
```

After Gate 3 approval:
```python
state["gates_passed"].append("G3")
state["current_wave"] = "D"
state["phase_file_loaded"] = false
```

## Common Mistakes (SHIP Phase)

| Mistake | Fix |
|---------|-----|
| DevOps defining SLOs | sre is sole SLO authority |
| DevOps writing runbooks | sre writes runbooks to docs/runbooks/ |
| Stopping pipeline on gate rejection | Gates are self-healing — rework loop, max 2 cycles |
| Not tracking rework cycles | Log to `.orchestrator/rework-log.md` |
| Trusting agent metrics without receipt verification | Gate metrics come from verified receipts, not memory |
| T12 waiting for SRE | T12 analyzes code patterns, not SRE output — launched in Wave A |
