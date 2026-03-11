# SHIP Phase — Dispatcher

This phase manages tasks T7 (DevOps IaC), T8 (Remediation), T9 (SRE), T10 (Data Scientist). Features PARALLEL #5 and #6.

## Visual Output

Print pipeline dashboard with SHIP ● active on phase start, then:

```
  → Starting SHIP phase
```

On PARALLEL #5 completion:
```
┌─ SHIP: Infra + Remediation COMPLETE ────── ⏱ {time} ─┐
│                                                        │
│  ✓ DevOps         {N} Terraform modules, {M} workflows │
│  ✓ Remediation    {N} Critical/{M} High fixed          │
│                                                        │
│  → Starting SRE + Data Scientist                       │
└────────────────────────────────────────────────────────┘
```

On PARALLEL #6 completion:
```
┌─ SHIP COMPLETE ───────────────────────────── ⏱ {time} ─┐
│                                                          │
│  ✓ SRE              {N} SLOs, {M} alerts, {K} runbooks  │
│  ✓ Data Scientist    {N} optimizations (or skipped)      │
│                                                          │
│  → Presenting Gate 3: Production Readiness               │
└──────────────────────────────────────────────────────────┘
```

## Authority Boundaries

- **devops** owns infrastructure provisioning, CI/CD, monitoring setup — does NOT define SLOs
- **sre** owns SLO/SLI definitions, error budgets, runbooks, chaos engineering — does NOT provision infrastructure
- See `Claude-Production-Grade-Suite/.protocols/conflict-resolution.md`

## Re-Anchor

Before creating SHIP agent tasks, re-read key artifacts from disk:
- `Claude-Production-Grade-Suite/security-engineer/` findings (code-audit/, auth-review/, remediation/)
- `Claude-Production-Grade-Suite/code-reviewer/` findings
- `Claude-Production-Grade-Suite/solution-architect/` workspace artifacts (architecture for infra)
- Directory listing of `services/`, `infrastructure/` (what exists)
- All HARDEN receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/`

Use this freshly-read data when writing agent task prompts below.

## SHIP Planning (opus planner)

Before dispatching PARALLEL #5, spawn a single opus planner that reads HARDEN findings and architecture artifacts, then writes execution plans for the sonnet agents. Skip this step if `Model-Optimization: disabled` in settings.

```python
# SHIP Planner — opus reasons about WHAT to fix/provision; sonnet agents implement
Agent(
  prompt="""You are the SHIP Planner. Your job: read HARDEN findings and architecture artifacts, then produce detailed, unambiguous execution plans for the SHIP agents.

Read these inputs:
- Claude-Production-Grade-Suite/security-engineer/ (all security findings — code-audit/, auth-review/, remediation/)
- Claude-Production-Grade-Suite/code-reviewer/ (all review findings)
- Claude-Production-Grade-Suite/qa-engineer/ (test results, failure reports)
- Claude-Production-Grade-Suite/solution-architect/ workspace artifacts (architecture for infra planning)
- docs/architecture/architecture-decision-records/*.md (architecture decisions)
- Directory listing of services/, frontend/, infrastructure/ (what exists)
- .production-grade.yaml (path overrides, framework preferences)

Write these plan files to Claude-Production-Grade-Suite/.orchestrator/plans/ship/:

1. **T7-infra-plan.md** — For each service in the architecture:
   - Terraform/Pulumi modules to create (full file path, resource types)
   - K8s manifests if microservices (deployments, services, ingress — exact specs)
   - CI/CD pipeline per service (stages, steps, triggers, environment variables)
   - Monitoring dashboards (which metrics, what thresholds)
   - Environment configuration (dev, staging, prod — what differs)
   - Explicit note: DO NOT define SLOs — placeholder only

2. **T8-remediation-plan.md** — For each Critical and High finding from HARDEN:
   - Finding ID, severity, affected file (full path), affected line range
   - Root cause analysis (what's wrong and why)
   - Exact fix instructions (what to change, not "fix the vulnerability")
   - Verification steps (which tests to run, what to re-scan)
   - Dependency order (if fix A must happen before fix B)
   - Medium/Low findings: list but mark as "document only, do not block"

Plans must be detailed enough that an agent can implement WITHOUT making judgment calls about severity or architecture.""",
  subagent_type="general-purpose",
  model="opus"  # Planner tier — always opus
)
```

## PARALLEL #5: T7 + T8

Read `Claude-Production-Grade-Suite/.orchestrator/settings.md` to check if `Worktrees: enabled`. If enabled, add `isolation="worktree"` to each Agent call below.

**IMPORTANT:** T7 and T8 MUST run as foreground agents (no `run_in_background`). Both Agent calls in the same message still execute concurrently, but the orchestrator blocks until both return — then naturally continues to worktree merge-back and PARALLEL #6. Using background agents here causes the orchestrator turn to end before merge-back can fire, losing worktree changes.

```python
# T7: DevOps IaC + CI/CD — executes SHIP plan
TaskUpdate(taskId=t7_id, status="in_progress")
Agent(
  prompt="""You are the DevOps Engineer — IaC and CI/CD.
Read your execution plan: Claude-Production-Grade-Suite/.orchestrator/plans/ship/T7-infra-plan.md
Implement EXACTLY what the plan specifies — Terraform modules, K8s manifests, CI/CD pipelines, monitoring.
Do not deviate from the plan. Do not make infrastructure decisions. The plan is your specification.

Use the Skill tool to invoke 'production-grade:devops' to load your complete methodology and follow it.
Read .production-grade.yaml for paths and preferences.
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Write to project root: infrastructure/, .github/workflows/
Write workspace artifacts to: Claude-Production-Grade-Suite/devops/
DO NOT define SLOs — add placeholder: "SLO thresholds defined by SRE."
DO NOT write runbooks — SRE writes runbooks to docs/runbooks/.
Validate: terraform validate, pipeline syntax lint.
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T7-devops.json with task, agent, phase, status, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T8: Remediation — executes SHIP plan (skip if no Critical/High findings)
# If HARDEN found zero Critical/High findings:
#   TaskUpdate(taskId=t8_id, status="completed")  # Skip — nothing to remediate
# If HARDEN found Critical/High findings:
TaskUpdate(taskId=t8_id, status="in_progress")
Agent(
  prompt="""You are the Remediation Engineer.
Read your execution plan: Claude-Production-Grade-Suite/.orchestrator/plans/ship/T8-remediation-plan.md
Follow the plan EXACTLY — fix each finding in the specified order, using the exact fix instructions provided.
Do not make severity judgments. Do not skip findings the plan marks as Critical/High. The plan is your specification.

For each finding in the plan:
  1. Read the affected file at the path specified
  2. Apply the fix exactly as described
  3. Run the verification steps specified in the plan
  4. Re-scan the affected code
If findings persist after 2 fix-rescan cycles → document and escalate.
Medium/Low findings: document but do not block (plan marks these explicitly).
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T8-remediation.json with task, agent, phase, status, artifacts (files modified), metrics (findings_fixed, findings_remaining), effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Omit if Worktrees: disabled
)
```

## PARALLEL #6: T9 + T10 (after T7 + T8 complete)

**IMPORTANT:** T9 and T10 MUST run as foreground agents (no `run_in_background`). Both Agent calls in the same message still execute concurrently, but the orchestrator blocks until both return — then naturally continues to worktree merge-back and Gate 3. Using background agents here causes the orchestrator turn to end before merge-back can fire, losing worktree changes.

```python
# T9 (SRE — Production Readiness, SOLE SLO AUTHORITY)
# T9 handles the full SRE scope: SLO definitions + execution (readiness review,
# chaos engineering, capacity planning). All SRE work happens here in SHIP.
TaskUpdate(taskId=t9_id, status="in_progress")
Agent(
  prompt="""You are the SRE — SOLE authority on SLO definitions, error budgets, runbooks, capacity planning.
Use the Skill tool to invoke 'production-grade:sre' to load your complete methodology and follow it.
Read all prior outputs: architecture, implementation, infrastructure, HARDEN findings.
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Perform production readiness review (checklist).
Define SLIs/SLOs per service, error budgets, burn-rate alerts.
Design chaos engineering scenarios and game-day playbook.
Write runbooks to project root: docs/runbooks/
Write workspace artifacts to: Claude-Production-Grade-Suite/sre/
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T9-sre.json with task, agent, phase, status, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="opus",  # Deep analysis tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T10: Data Scientist (conditional — auto-detect LLM/ML usage)
# Before launching T10, run: Grep(pattern="(openai|anthropic|langchain|transformers|torch|tensorflow)",
#   glob="*.{py,ts,js,go,rs}", output_mode="count", head_limit=1)
# If matches > 0 OR features.ai_ml is true in .production-grade.yaml → launch T10:
# If no matches AND features.ai_ml is not true → skip: TaskUpdate(taskId=t10_id, status="completed")
TaskUpdate(taskId=t10_id, status="in_progress")
Agent(
  prompt="""You are the Data Scientist.
Use the Skill tool to invoke 'production-grade:data-scientist' to load your complete methodology and follow it.
Read implementation for LLM/ML usage patterns (imports, API calls, prompts).
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Optimize: prompt engineering, token usage, semantic caching, fallback chains.
Design: A/B testing infrastructure, experiment framework, data pipeline.
Write workspace artifacts to: Claude-Production-Grade-Suite/data-scientist/
When complete, write a receipt JSON to Claude-Production-Grade-Suite/.orchestrator/receipts/T10-data-scientist.json with task, agent, phase, status, artifacts, metrics, effort, verification. Then mark your task as completed.""",
  subagent_type="general-purpose",
  model="opus",  # Deep analysis tier — omit if Model-Optimization: disabled
  isolation="worktree"  # Omit if Worktrees: disabled
)
# If NOT detected AND features.ai_ml is false:
#   TaskUpdate(taskId=t10_id, status="completed")  # Skip
```

## PARALLEL #5 Worktree Merge-Back

If worktrees were used, merge PARALLEL #5 branches back **before** re-verification and PARALLEL #6:

Collect worktree branch names from each Agent result — the result text includes the branch name (e.g., `branch: production-grade-agent-XXXXX`). Parse and store these when processing each Agent's return.

```python
# After PARALLEL #5 (T7 + T8) — merge BEFORE re-verification:
for branch in ship_p5_worktree_branches:  # [t7_branch, t8_branch]
  Bash(f"git merge --no-ff {branch} -m 'production-grade: merge {branch}'")
  Bash(f"git branch -d {branch}")
# If merge conflicts: git merge --abort, escalate to user
```

## Re-Verification After Remediation

After T8 (Remediation) completes and its PARALLEL #5 worktree is merged, re-scan the affected files to verify fixes. This runs **between PARALLEL #5 merge and PARALLEL #6 launch** so T9 (SRE) sees verified code.

```python
# Only runs if T8 remediated Critical/High findings
# Read T8 receipt to get list of files modified
t8_receipt = Read("Claude-Production-Grade-Suite/.orchestrator/receipts/T8-remediation.json")
# Extract affected_files from t8_receipt.artifacts

# Re-scan: the ORIGINAL finding agents verify their findings are resolved
Agent(
  prompt="""You are the Remediation Verifier.
Read the T8 remediation receipt: Claude-Production-Grade-Suite/.orchestrator/receipts/T8-remediation.json
For each file listed in the receipt's artifacts:
  1. Read the file
  2. Check that each Critical/High finding from the original HARDEN reports is resolved
  3. Re-run relevant security checks (OWASP patterns) and code quality checks
  4. For each finding: mark as VERIFIED (fixed) or UNRESOLVED (still present)

Read original findings from:
- Claude-Production-Grade-Suite/security-engineer/ (code-audit/, auth-review/, remediation/)
- Claude-Production-Grade-Suite/code-reviewer/

Write verification receipt to:
Claude-Production-Grade-Suite/.orchestrator/receipts/T8-verification.json
with: task, agent, phase, status, findings_verified, findings_unresolved, artifacts, effort.

If any Critical finding is UNRESOLVED after remediation, flag it clearly in the receipt.""",
  subagent_type="general-purpose",
  model="opus"  # Verification requires judgment
)
```

**After re-verification completes, proceed to PARALLEL #6 (T9 + T10).**

## PARALLEL #6 Worktree Merge-Back

After PARALLEL #6 (T9 + T10) completes, merge their worktree branches:

```python
# After PARALLEL #6 (T9 + T10):
for branch in ship_p6_worktree_branches:  # [t9_branch, t10_branch]
  Bash(f"git merge --no-ff {branch} -m 'production-grade: merge {branch}'")
  Bash(f"git branch -d {branch}")
# If merge conflicts: git merge --abort, escalate to user
```

## Receipt Verification Before Gate 3

After T9 (and T10 if applicable) completes and worktrees are merged:
1. **Verify all SHIP receipts:** Read `Claude-Production-Grade-Suite/.orchestrator/receipts/T7-devops.json`, `T8-remediation.json`, `T8-verification.json`, `T9-sre.json`, `T10-data-scientist.json` (if applicable). Verify all listed artifacts exist.
2. **Verify remediation chain:** For each Critical/High finding from HARDEN, check that `T8-verification.json` marks it as VERIFIED. If any Critical finding is UNRESOLVED, flag before Gate 3.
3. **Aggregate metrics** from all receipts for Gate 3 display — use verified receipt data, not memory.

## Gate 3 — Production Readiness

After verification, present Gate 3 using the orchestrator's gate pattern.

On approval → read `phases/sustain.md` and begin SUSTAIN phase.
On "Fix issues first" → create additional remediation tasks.
