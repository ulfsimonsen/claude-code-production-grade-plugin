# Wave B — Dispatcher

This phase manages Wave B: T4b (container build), T5b (QA execution), T6c (security audit), T6d (code review), T7 (IaC + CI/CD). All 5 foreground with worktree. These agents execute against code using Wave A analysis plans.

## Authority Boundaries — CRITICAL

Enforce these boundaries strictly:
- **security-engineer** is SOLE authority on OWASP Top 10, STRIDE, PII, encryption
- **code-reviewer** does architecture conformance, code quality, performance — does NOT perform security review
- **code-reviewer** is READ-ONLY — produces findings and patch files, does NOT modify source code
- See `Claude-Production-Grade-Suite/.protocols/conflict-resolution.md` for full authority table

## Re-Anchor

Before creating Wave B agent tasks, re-read key artifacts from disk:
- `Claude-Production-Grade-Suite/solution-architect/` workspace artifacts (working-notes.md, analysis/*.md)
- `docs/architecture/architecture-decision-records/*.md` (Glob to list)
- Directory listing of `services/`, `frontend/`, `libs/shared/` (what BUILD actually produced)
- `Claude-Production-Grade-Suite/.orchestrator/receipts/T3a-*.json`, `T3b-*.json` (BUILD receipts — what was built, metrics)

Use this freshly-read data when writing agent task prompts below.

## Wave B Readiness Check

Before launching Wave B, verify that background analysis outputs from Wave A exist on disk. These agents ran in background during Wave A — their outputs are required for Wave B agents.

```python
# Required analysis outputs — Wave B agents read these
readiness = {
  "T5a test plan": "Claude-Production-Grade-Suite/qa-engineer/test-plan.md",
  "T6a STRIDE model": "Claude-Production-Grade-Suite/security-engineer/threat-model/",
  "T6b review checklist": "Claude-Production-Grade-Suite/code-reviewer/checklist.md",
  "T4a Dockerfiles": "Claude-Production-Grade-Suite/devops/dockerfiles/",
}

# Check each exists on disk
for name, path in readiness.items():
  exists = Glob(path) or Read(path)  # Glob for dirs, Read for files
  if not exists:
    # Background agent still running or failed
    print(f"  ⧖ Waiting for {name}...")
    # Wait briefly, then re-check. If still missing after ~60s,
    # fall back to inline analysis (Wave B agent does its own analysis)
```

For optional outputs (T9a SLOs, T11a API ref, T12 skills), don't wait — these aren't needed by Wave B agents.

## Visual Output

Print pipeline dashboard with HARDEN ● active on phase start. Then print wave announcement:
```
┌─ WAVE B ──────────────────────────────── 5 agents ─┐
│                                                      │
│  T4b  DevOps       build containers (code + T4a)     │
│  T5b  QA Engineer  implement tests (code + T5a plan) │
│  T6c  Security     code audit (code + T6a STRIDE)    │
│  T6d  Code Review  review code (code + T6b checklist)│
│  T7   DevOps IaC   Terraform + CI/CD (code + arch)   │
│                                                      │
│  All agents launched. Working autonomously...        │
└──────────────────────────────────────────────────────┘
```

## FOREGROUND: T4b + T5b + T6c + T6d + T7

Read `Claude-Production-Grade-Suite/.orchestrator/settings.md` to check if `Worktrees: enabled`. If enabled, add `isolation="worktree"` to each Agent call below.

**IMPORTANT:** All 5 agents MUST run as foreground agents (no `run_in_background`). All 5 Agent calls in the same message execute concurrently, but the orchestrator blocks until all return — then continues to worktree merge-back and Wave C.

```python
# T4b: DevOps — build containers from code + T4a Dockerfiles
TaskUpdate(taskId=t4b_id, status="in_progress")
Agent(
  prompt="""You are the DevOps Container Builder.
Read Dockerfiles from Claude-Production-Grade-Suite/devops/dockerfiles/ (written by T4a).
Read docker-compose draft from Claude-Production-Grade-Suite/devops/compose-draft.yml.
Read actual service code from services/ and frontend/ to finalize build contexts.
Build and validate containers: docker build succeeds for each service.
Write final Dockerfiles to project root (per service) and docker-compose.yml.
Write workspace artifacts to: Claude-Production-Grade-Suite/devops/
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T4b-devops-build.json.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T5b: QA — implement tests from T5a test plan
TaskUpdate(taskId=t5b_id, status="in_progress")
Agent(
  prompt="""You are the QA Engineer — Test Implementer.
Read your test plan: Claude-Production-Grade-Suite/qa-engineer/test-plan.md (written by T5a).
Use the Skill tool to invoke 'production-grade:qa-engineer' to load your methodology.
Implement the tests specified in the plan against actual code in services/ and frontend/.
Read protocols from: Claude-Production-Grade-Suite/.protocols/
Read .production-grade.yaml for paths.tests and paths.services.
Write tests to project root: tests/
Write workspace artifacts to: Claude-Production-Grade-Suite/qa-engineer/
Run all tests. Distinguish test bugs (fix immediately) from implementation bugs (log as findings).
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T5b-qa-engineer.json.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T6c: Security — code audit using T6a STRIDE model (SOLE OWASP AUTHORITY)
TaskUpdate(taskId=t6c_id, status="in_progress")
Agent(
  prompt="""You are the Security Engineer — Code Auditor. SOLE authority on OWASP, STRIDE, PII, encryption.
Read your STRIDE threat model: Claude-Production-Grade-Suite/security-engineer/threat-model/ (written by T6a).
Use the Skill tool to invoke 'production-grade:security-engineer' to load your methodology.
Audit all implementation code in services/, frontend/, infrastructure/ against the threat model.
Perform dependency scanning, auth flow review, data security review.
Write findings to: Claude-Production-Grade-Suite/security-engineer/code-audit/, auth-review/, data-security/, supply-chain/
Do NOT auto-fix code — write findings only. Critical/High fixes handled by T8 in Wave C.
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T6c-security-audit.json.""",
  subagent_type="general-purpose",
  model="opus",  # Deep analysis tier
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T6d: Code Review — execute review using T6b checklist (NO OWASP)
TaskUpdate(taskId=t6d_id, status="in_progress")
Agent(
  prompt="""You are the Code Reviewer — architecture conformance and code quality ONLY.
Read your review checklist: Claude-Production-Grade-Suite/code-reviewer/checklist.md (written by T6b).
Use the Skill tool to invoke 'production-grade:code-reviewer' to load your methodology.
DO NOT perform OWASP, STRIDE, or any security review — security-engineer is sole authority.
Read architecture: docs/architecture/, api/
Read implementation: services/, frontend/
Review against checklist: SOLID/DRY/KISS, performance, N+1 queries, resource leaks, test quality.
Write findings to: Claude-Production-Grade-Suite/code-reviewer/
READ-ONLY: produce findings only, do NOT modify source code.
ADVERSARIAL STANCE: assume code is wrong until proven right.
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T6d-code-reviewer.json.""",
  subagent_type="general-purpose",
  model="opus",  # Deep analysis tier
  isolation="worktree"  # Omit if Worktrees: disabled
)

# T7: DevOps IaC + CI/CD (needs architecture + service structure, NOT HARDEN findings)
TaskUpdate(taskId=t7_id, status="in_progress")
Agent(
  prompt="""You are the DevOps Engineer — IaC and CI/CD.
Read architecture from docs/architecture/ and service structure from services/.
Read .production-grade.yaml for paths and preferences.
Use the Skill tool to invoke 'production-grade:devops' to load your methodology.
Write Terraform/Pulumi modules for infrastructure provisioning.
Write CI/CD pipeline configs (.github/workflows/ or equivalent).
Write monitoring dashboard configs.
DO NOT define SLOs — add placeholder: "SLO thresholds defined by SRE."
DO NOT write runbooks — SRE writes runbooks to docs/runbooks/.
Write to project root: infrastructure/, .github/workflows/
Write workspace artifacts to: Claude-Production-Grade-Suite/devops/
Validate: terraform validate, pipeline syntax lint.
When complete, write a receipt JSON (including completed_at) to Claude-Production-Grade-Suite/.orchestrator/receipts/T7-devops-iac.json.""",
  subagent_type="general-purpose",
  model="sonnet",  # Executor tier
  isolation="worktree"  # Omit if Worktrees: disabled
)
```

## Worktree Merge-Back

After all 5 Wave B agents complete, merge their worktree branches:

```python
for branch in wave_b_worktree_branches:  # [t4b, t5b, t6c, t6d, t7]
  Bash(f"git merge --no-ff {branch} -m 'production-grade: merge {branch}'")
  Bash(f"git branch -d {branch}")
# Stale worktrees auto-cleaned (2.1.76+). Merge conflicts escalated to user.
```

## Post-Wave B: Receipt Verification & Findings Summary

After all Wave B tasks complete:
1. **Verify receipts:** Read all Wave B receipts (T4b, T5b, T6c, T6d, T7). Verify all listed artifacts exist on disk.
2. Collect all findings from T5b, T6c, T6d workspace folders
3. Deduplicate by file:line — keep highest severity rating
4. Filter Critical/High severity findings
5. If any Critical/High exist → T8 (Remediation in Wave C) receives the findings list
6. Medium/Low → documented but do not block pipeline
7. Print the checkmark cascade, then findings summary:
```
┌─ WAVE B COMPLETE ─────────────────────── ⏱ {time} ─┐
│                                                      │
│  ✓ DevOps             {N} containers built           │
│  ✓ QA Engineer        {N} tests, {M} passing         │
│  ✓ Security Engineer  {N} findings ({M} Crit/High)   │
│  ✓ Code Reviewer      {N} findings ({M} Crit/High)   │
│  ✓ DevOps IaC         {N} Terraform modules          │
│                                                      │
│  5/5 complete                                        │
└──────────────────────────────────────────────────────┘

━━━ Findings ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Critical   {N}    {top finding description}
                    {second finding if applicable}
  High       {N}    {summary}
  Medium     {N}    —
  Low        {N}    —
  ─────────────
  Total      {N}    deduplicated by file:line

  → {N} Critical/High items entering remediation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Handoff to Wave C

**Re-anchor:** Before transitioning, re-read from disk:
- `Claude-Production-Grade-Suite/security-engineer/` findings (code-audit/, auth-review/)
- `Claude-Production-Grade-Suite/code-reviewer/` findings
- `Claude-Production-Grade-Suite/qa-engineer/` test results
- `infrastructure/` listing (what T7 created)
- All Wave B receipts from `Claude-Production-Grade-Suite/.orchestrator/receipts/`

Read `phases/ship.md` and begin Wave C — use freshly-read findings data for remediation agent prompt.
