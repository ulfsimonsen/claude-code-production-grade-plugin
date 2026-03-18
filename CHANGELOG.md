# Changelog

All notable changes to the Production Grade Plugin.

## [7.1.0] — 2026-03-18

### Added
- **Automatic targeted test execution** — PostToolUse(Write|Edit) hook runs only the relevant test subset when plugin source files are modified. Static manifest (`tests/manifest.json`) maps 28 source file patterns to test suites. Convention fast-path resolves hook→test in <1ms. Fast-path string check skips jq entirely for non-plugin files (~1ms overhead per external Write/Edit vs ~50ms without optimization).
- **Targeted test runner** (`tests/run-targeted.sh`) — Accepts relative file paths, resolves tests via convention then manifest pattern matching, deduplicates, runs, and reports machine-parseable summary. Always exits 0 (advisory).
- **Test runner hook** (`hooks/test-runner.sh`) — PostToolUse hook with `Write|Edit` matcher. Returns advisory context with pass/fail counts. Never blocks.
- **6-layer defense-in-depth enforcement** — Graduated deny system in phase-loader.sh: denies Agent dispatch when phase not loaded (twice), then falls back to allow+inject critical directives to prevent deadlock. Deny counter tracked via temp files, reset on phase load.
- **State validator hook** (`hooks/state-validator.sh`) — Validates state.json on every write: phase_file_loaded requires timestamp, tasks_active requires valid phase, COMPLETE phase has no active tasks, staleness warning >30min. Advisory only.
- **Critical directive injection** — 5 per-phase critical directive files (`phases/critical/*.txt`) injected into every pipeline subagent by subagent-phase-injector.sh, ensuring mandatory steps reach agents regardless of orchestrator behavior.
- **Active cleanup enforcement** — pipeline-cleanup.sh writes cleanup-pending marker with specific steps (TeamDelete, CLAUDE.md directive, plugin data persistence) when session ends mid-pipeline. session-guard.sh detects marker on startup/resume and injects mandatory cleanup instructions.
- **13 new test suites** — session-guard, pipeline-cleanup, state-validator, critical-directives, phase-loader (rewritten), elicitation-validator, elicitation-result-logger, instructions-loaded-guard, post-compact-guard, stop-failure-guard, teammate-idle-guard, worktree-tracker, framework meta-tests. Hook test coverage: 50%→100% (16/16 hooks). Total: 24 suites, 596 assertions.
- **Settings validation tests** (`tests/test-settings.sh`) — Validates JSON structure, sandbox config, network hosts, filesystem deny rules, allow/deny lists. 53 assertions.

### Changed
- **Test count** expanded from 184 to 596 assertions across 24 suites (was 11 suites)
- **hooks.json** — 2 new PostToolUse entries: state-validator (Write), test-runner (Write|Edit)
- **phase-loader.sh** — Deny-first enforcement replaces advisory-only behavior
- **subagent-phase-injector.sh** — Now injects critical directives from phases/critical/*.txt
- **pipeline-cleanup.sh** — Upgraded from passive logger to active cleanup executor
- **test-schemas.sh** — Expanded from 2 task schemas (T1, T3a) to all 21 (T1–T13)
- **Framework helpers** — `assert_file_contains`/`assert_file_not_contains` deduplicated into framework.sh

### Fixed
- **settings.json permissions** — Added Read to allow list (fixes subagent prompts), renamed allowedDomains→allowedHosts (correct field name), restored * wildcard for unrestricted WebFetch
- **session-guard.sh** — Fixed operator precedence bug in cleanup-pending detection (&&/|| evaluated wrong)

## [7.0.0] — 2026-03-18

### Added
- **Self-Improvement mode (Improve)** — 12th execution mode. Focused iteration loop on a single agent, skill, or agent+skill pair. Dedicated evaluator agent scores output against binary rubric criteria. Composite termination: TIME, THRESHOLD, MAX_ITERATIONS, MAX_EVALUATIONS. Uses SendMessage for agent continuation across iterations. Python utility scripts created opportunistically. Meta-improvement: the agent/skill DEFINITION evolves across iterations.
- **Evaluator agent** — 15th skill. Binary rubric-based scoring of agent/skill output. Read-only (disallowedTools enforced). Extractable as standalone project.
- **Elicitation protocol** — 9th shared protocol. All user input via MCP Elicitation (replaces AskUserQuestion). Free-form escape hatch in every form. Engagement mode scaling preserved.
- **Agent frontmatter** — All 15 SKILL.md files gain `effort`, `maxTurns`, `disallowedTools` declarative configuration (Claude Code 2.1.78). Analysis agents structurally enforced as read-only.
- **Persistent plugin state** — `${CLAUDE_PLUGIN_DATA}` stores user preferences and pipeline analytics across sessions. InstructionsLoaded hook loads preferences at startup.
- **7 new hook scripts** — StopFailure (API error handling), InstructionsLoaded (preference loading), Elicitation validator/logger, WorktreeCreate/Remove trackers, pipeline cleanup on Stop. hooks.json: 8→15 entries.
- **Cron-based monitoring** — Post-pipeline health checks (test re-runs, security scans, dependency audits). Configurable via .production-grade.yaml.
- **SendMessage agent lifecycle** — Background agents resumable via SendMessage(to: agentId). Agent IDs tracked in state.json.
- **3 new test suites** — test-frontmatter.sh (15 tests), test-elicitation-protocol.sh (12 tests), test-improve-mode.sh (17 tests). Total: 184 tests across 11 suites.

### Changed
- **Minimum Claude Code version** bumped to 2.1.78+ (from 2.1.76+)
- **Execution modes** expanded from 11 to 12 (Improve mode added)
- **Agent count** expanded from 14 to 15 (Evaluator added)
- **Protocol count** expanded from 8 to 9 (Elicitation Protocol added)
- **AskUserQuestion fully replaced** with MCP Elicitation across all skills, phase dispatchers, gate ceremonies
- **UX Protocol** slimmed from 6 rules to 3 (input rules moved to Elicitation Protocol)
- **Receipt protocol** field names aligned with JSON schemas (task_id, skill, status: completed)
- **Runtime model param removed** from phase dispatchers — frontmatter is single source of truth
- **DEV_PROTOCOL.md** updated for 15 agents, 9 protocols, Elicitation standard

### Fixed
- **Race conditions in state.json** — flock-based file locking added to receipt-validator.sh, worktree-create-tracker.sh, worktree-remove-tracker.sh
- **Dead schema removed** — receipt-evaluator.schema.json was unreachable; deleted
- **Heredoc injection risk** in 4 hook scripts documented as known Medium
- **Stale AskUserQuestion references** in session-guard.sh, ux-protocol.md table header, SKILL.md protocol descriptions

## [6.0.0] — 2026-03-16

### Added
- **Auto engagement mode** — Fully autonomous execution with ZERO user interaction throughout the entire development cycle. The user invokes `/production-grade auto` (or says "autonomous", "hands-off", "walk away") and the pipeline runs start-to-finish without a single `AskUserQuestion` call. Triggered via request classification, engagement mode selection, or `/production-grade auto` shorthand.
- **Branch isolation** — Auto mode always creates an isolated branch (`auto/production-grade/{project-slug}-{timestamp}`) before any work. Dirty repos are auto-committed. The user's working branch is never modified. Final summary includes `git merge` instructions for review-then-merge workflow.
- **Permissions pre-flight** — Auto mode checks `.claude/settings.json` for all required tool permissions (`Write(*)`, `Edit(*)`, `Bash(git *)`, `Agent(*)`, etc.) before starting. If any are missing, it prints exact JSON to add and stops — the only interaction point in the entire Auto pipeline.
- **Auto-derive PM and Architect** — In Auto mode, T1 (Product Manager) and T2 (Solution Architect) spawn as `Agent` calls with auto-derive prompts instead of invoking Skills (which would try to interview the user). PM auto-derives BRD from the user's request + WebSearch. Architect auto-derives architecture from BRD.
- **Gate auto-approval** — All 3 pipeline gates (BRD, Architecture, Production Readiness) auto-approve with `[AUTO-APPROVED]` ceremony. Receipts are still verified and artifacts checked on disk — failures are logged but never block. No rework loops in Auto mode.
- **Auto decisions log** — Every autonomous decision is logged to `Claude-Production-Grade-Suite/.orchestrator/auto-decisions.md` with reasoning. The final summary prints the complete decisions log so users can review what was decided on their behalf.
- **Known issues tracking** — Unresolved Critical/High findings that survive remediation are collected as known issues in the Auto mode final summary, with severity, description, and file:line references.
- **Auto mode test suite** — 57 structural consistency tests (`tests/test-auto-mode.sh`) verifying Auto mode instructions are present and cross-referenced correctly across all 6 modified files: SKILL.md, define.md, build.md, ship.md, sustain.md, ux-protocol.md.

### Changed
- **Engagement mode expanded** — Settings format now includes `auto` as a valid engagement level: `Engagement: [auto|express|standard|thorough|meticulous]`. All phase dispatchers check for `Engagement: auto` and bypass all interaction when detected.
- **UX Protocol Rule 6** — Added `Auto` row to the engagement mode table with "Total autonomy" posture. Documented Auto vs Express differences (Express still fires 3 gates; Auto fires zero). Updated gate/escalation exceptions for Auto mode.
- **Gate ceremonies** — All 3 gate sections (define.md Gate 1/2, ship.md Gate 3) restructured into `Auto Mode — Gate N Auto-Approve` and `Standard Mode — Gate N (non-Auto)` subsections for clarity.
- **Build phase** — Worktree pre-flight auto-commits dirty repos in Auto mode without asking. Frontend style selection auto-selects in Auto/Express modes. Failure handling logs and proceeds in Auto mode instead of escalating.
- **Sustain phase** — Assembly step restructured into `Auto Mode Assembly` (auto-integrate, no question) and `Standard Mode Assembly` (AskUserQuestion). Auto mode does not switch branches after completion — leaves user on the auto branch for review.
- **Execution modes count** — Increased from 10 to 11 (Auto mode added). README badges updated.

### Fixed
- **CDPATH bug in test framework** — `framework.sh` and `run-all.sh` now redirect `cd` stdout to `/dev/null`, preventing `CDPATH`-triggered double-path output from breaking `PROJECT_ROOT`/`SCRIPT_DIR` resolution. Previously caused all tests to fail in shells with `CDPATH` set.

## [5.9.0] — 2026-03-16

### Added
- **Hook-enforced JIT loading** — 5 new hooks (`SubagentStart`, `PreToolUse(Agent)`, `PostToolUse(Write)`, `TaskCompleted`, `PreCompact`) enforce pipeline discipline structurally. SubagentStart injects phase/wave context into every pipeline agent. PreToolUse reminds orchestrator to read phase files before dispatching. PostToolUse validates receipt JSON against schemas after every write to receipts/. TaskCompleted blocks completion without valid receipt (exit 2). PreCompact snapshots pipeline state before context compression.
- **JSON schema gate validation** — 25 schemas (1 base, 21 per-task, 3 gate) validate required fields, metric minimums, and artifact existence. Receipt validator auto-updates `state.json` on valid writes. Task-specific schemas define `required_metrics` and `min_values` checked at write time.
- **Test suite** — 127 tests across 7 suites validating all 5 hook scripts, 25 JSON schemas, and `hooks.json` configuration. Lightweight bash framework with `assert_eq`, `assert_contains`, `assert_json_valid`, and workspace scaffolding helpers. Each test creates an isolated temp workspace, pipes mock hook input, and asserts on exit codes, stdout JSON, stderr messages, and side effects.
- **Pre-commit hook** — `git-hooks/pre-commit` runs the test suite automatically when `hooks/`, `skills/production-grade/schemas/`, or `tests/` files are staged. Skips silently for unrelated commits. Setup: `git config core.hooksPath git-hooks`.

### Changed
- **Lean Router SKILL.md** — slimmed from 84K to 39K bytes (~54% reduction) by moving execution details (gate ceremonies, task dependency graphs, model tier strategy, context bridging, final summary template, common mistakes, pipeline cleanup) into phase dispatcher files loaded just-in-time.
- **Phase dispatchers enriched** — `define.md`, `build.md`, `harden.md`, `ship.md`, `sustain.md` now contain full gate ceremonies, task dependency tables, context bridging, state management, and phase-specific mistakes that were previously in SKILL.md.

## [5.8.0] — 2026-03-14

### Changed
- **4-wave architecture replaces 5-phase model** — pipeline now executes as Wave A (9 agents: 2 foreground build + 7 background analysis), Wave B (5 foreground agents execute against code using analysis plans), Wave C (3 agents: remediation + SRE execution + data scientist), Wave D (2 agents: ops guide + final assembly). Reduces serial steps from 7 to 4 after Gate 2. Background analysis agents run alongside build agents — code is written and merged faster while analysis runs on the non-critical path.
- **Corrected 5 false task dependencies** — T7 (IaC) no longer waits for HARDEN findings (moved to Wave B, needs architecture + services only). T9 split into T9a (SLO definitions, Wave A background) + T9b (chaos/capacity, Wave C). T10 (Data Scientist) unblocked from T7/T8 (needs code only). T11 split into T11a (API ref, Wave A background) + T11b (ops guide, Wave D). T12 (Skill Maker) unblocked from T9/T10 (moved to Wave A background).
- **Background agents for analysis tasks** — T4a, T5a, T6a, T6b, T9a, T11a, T12 now run as `run_in_background=True` without worktree isolation. They write to `Claude-Production-Grade-Suite/` workspace dirs only. Safe since Claude Code 2.1.76 preserves partial results when background agents are killed.
- **Minimum Claude Code version** bumped to 2.1.76+ (from 2.1.72+). Required for PostCompact hook, background agent partial results, stale worktree auto-cleanup, worktree sparse paths, and token estimation fix.

### Added
- **PostCompact hook** — new `PostCompact` hook (`hooks/post-compact-guard.sh`) fires after context compaction completes. Injects pipeline state summary (current wave, last completed task, next dispatcher) into the fresh post-compaction context. Survives compaction because it's injected after, not before. Replaces the `compact` matcher in SessionStart which fired pre-compaction and could be compressed.
- **Receipt timestamps** — `completed_at` (ISO-8601) field added to receipt protocol. Enables per-agent elapsed time tracking, bottleneck identification in compound learning (T13), and real `⏱` timing values in the final summary instead of streaming estimates.
- **Worktree sparse checkout** — `worktree.sparsePaths` added to `.claude/settings.json` excluding `node_modules/`, `dist/`, build artifacts from worktree clones. Users can override via `.production-grade.yaml`. Speeds up worktree creation for large repos.
- **Wave B readiness check** — before launching Wave B, the dispatcher verifies that all required background analysis outputs (test plan, STRIDE model, review checklist, Dockerfiles) exist on disk. Falls back to inline analysis if a background agent failed.
- **Context bridging table** updated with split task entries (T4a/T4b, T5a/T5b, T6a/T6c, T6b/T6d, T9a/T9b, T11a/T11b).
- **4 new common mistakes** — false dependency patterns (T7 waiting for HARDEN, T12 waiting for SRE, T11 fully blocked on SRE), background agents incorrectly using worktrees.

### Fixed
- **SessionStart hook handled compaction incorrectly** — `compact` matcher in SessionStart fired before compaction, so re-orientation message could be compressed. Moved to PostCompact hook. SessionStart matcher changed from `startup|clear|compact` to `startup|clear`.
- **Worktree known issues overstated** — stale worktrees from interrupted runs are auto-cleaned in 2.1.76+. Updated SKILL.md known issues and common mistakes table. Simplified merge-back failure comments in all dispatchers.
- **Re-anchoring table used old phase names** — updated from DEFINE→BUILD→HARDEN→SHIP→SUSTAIN to DEFINE→Wave A→Wave B→Wave C→Wave D with corrected artifact lists per transition.

### Improved (from Claude Code 2.1.75/2.1.76 upstream)
- **1M context default for Opus 4.6** — Max, Team, Enterprise plans get full 1M context without extra usage. Fewer compaction events during Full Build mode.
- **Token estimation fix** — prevents premature compaction from over-counting thinking/tool_use blocks. Long pipeline runs are more reliable.
- **Auto-compaction circuit breaker** — stops retrying after 3 consecutive failures instead of looping indefinitely.
- **Stale worktree auto-cleanup** — worktrees from interrupted parallel runs are automatically cleaned up.
- **Worktree startup performance** — reads git refs directly, skips redundant `git fetch`.
- **Background agent partial results** — killing a background agent preserves partial results in context. Enables the background analysis agent pattern.
- **Bash `!` fix** — `jq 'select(.x != .y)'` and similar commands with `!` in quoted args now work correctly. Affects QA and DevOps agents.

## [5.7.6] — 2026-03-12

### Fixed
- **Replace manual auto-update with Claude Code plugin CLI** — removed fragile 38-line update mechanism (git clone to temp, manual cp to cache, manual JSON editing of installed_plugins.json, rm cleanup) that failed in sandbox mode. Replaced with two CLI commands: `claude plugin marketplace update` + `claude plugin update`. Fully sandbox-safe, no temp files, delegates version management to Claude Code's built-in plugin infrastructure.
- **DEV_PROTOCOL still referenced manual 4-location version bumping** — reduced from "4 places, all must match" to 2 (plugin.json + marketplace.json). Removed instructions to manually copy files to cache and edit installed_plugins.json. Updated development workflow and golden rules to use CLI commands.

## [5.7.5] — 2026-03-12

### Fixed
- **Wrong paths in DEV_PROTOCOL version bumping checklist** — marketplace.json path pointed to `~/nagi_plugins/ulfsimonsen-plugins/`, installed_plugins.json referenced `production-grade@ulfsimonsen`, and cache path used `ulfsimonsen/production-grade/`. Updated all 3 to match actual filesystem: `~/dev/claude-plugins/local-marketplace/`, `cc-production-grade@local-marketplace`, `local-marketplace/cc-production-grade/`.

## [5.7.4] — 2026-03-12

### Fixed
- **Auto-update WebFetch blocked by sandbox** — `raw.githubusercontent.com` missing from `.claude/settings.json` network hosts. Auto-update check silently failed due to sandbox network restrictions. Added to `allowedHosts`.
- **`CLAUDE_ENV_FILE` unreliable for plugin hooks** — session-guard.sh wrote effort level to `$CLAUDE_ENV_FILE`, but this variable can be empty for plugin-provided hooks (GitHub #11649). Added `-w` (writable) check alongside `-n` (non-empty) check. Comment documents the known limitation.
- **Session guard re-prompts on `--resume` during active pipeline** — when resuming a session with `--resume`/`--continue`, the `source` field is `"resume"` but the guard only handled `"compact"` and `"clear"`, falling through to the full guard prompt every resume. Now handles `"resume"` the same as compact/clear — re-orients without re-prompting when a pipeline is active. Per Claude Code 2.1.73 fix (SessionStart hooks now fire once, not twice, on resume).
- **Skill-maker writes to sandbox-blocked `.claude/skills/`** — Claude Code v2.1.38 blocks writes to `.claude/skills/` in sandbox mode (skills are executable code). skill-maker SKILL.md, sustain.md T12 prompt, and SKILL.md context bridging table updated to stage skills to `Claude-Production-Grade-Suite/skill-maker/skills/` with user install instructions. Final assembly step in sustain.md now includes skill install guidance.
- **`TeamDelete` can block indefinitely on hung agents** — GitHub #31788 documents that `TeamDelete` has no timeout or force-kill when an agent is unresponsive. Added warning in pipeline cleanup section and common mistakes table. The `pipeline-status` marker + TeammateIdle hook provide a safety net.
- **Worktree isolation + permission issues undocumented** — GitHub #29110 documents that `isolation="worktree"` combined with permission prompts can block agents on Write/Edit/Bash operations, and worktrees can be silently deleted if agents don't commit. Added known limitation note to worktree requirements, and 3 new common mistakes table entries for worktree permission errors, data loss, and TeamDelete hanging.

## [5.7.3] — 2026-03-12

### Fixed
- **Restore `TeamCreate`/`TeamDelete`** — these are valid experimental agent team tools (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`), not phantom tools. Restored `TeamCreate(team_name="production-grade")` at pipeline start (SKILL.md step 10), `TeamDelete(team_name="production-grade")` at pipeline cleanup (SKILL.md, sustain.md), and the common mistakes table entry. Restored TeammateIdle hook comment referencing TeamDelete as primary cleanup.

## [5.7.2] — 2026-03-12

### Fixed
- **Phantom `mode="bypassPermissions"` on Agent calls** — removed from all 15 Agent dispatch calls across 7 files (SKILL.md, build.md, harden.md, ship.md, sustain.md, software-engineer, frontend-engineer). Not a valid parameter on the Agent tool; permission mode is a session-level setting, not per-agent.
- **Phantom `TeamCreate`/`TeamDelete` calls** — removed from SKILL.md (step 10, pipeline cleanup) and sustain.md. These tools do not exist; cleanup now relies on the `pipeline-status` marker and the TeammateIdle hook.
- **`run_in_background=True` on skill-internal Agent calls** — removed from software-engineer and frontend-engineer SKILL.md. Background agents break the orchestrator's execution chain; multiple foreground Agent calls in the same message already execute concurrently.
- **Grep parameter order in tool-efficiency protocol** — `Grep("className", pattern="*.ts")` → `Grep(pattern="className", glob="*.ts")`. First positional argument is `pattern`, file filter is `glob`.
- **Bash `cat` in input-validation protocol** — `cat .production-grade.yaml` → `Read(".production-grade.yaml")` to follow the tool-efficiency protocol's own Rule 3.
- **Missing protocol auto-loads in SKILL.md** — added 4 missing `!cat` directives for `ux-protocol.md`, `input-validation.md`, `tool-efficiency.md`, `conflict-resolution.md` in the frontmatter.
- **Missing settings auto-load in skill-maker** — added `!cat Claude-Production-Grade-Suite/.orchestrator/settings.md` to frontmatter so engagement mode is available.
- **`system-design.md` references** — replaced 6 references to nonexistent `solution-architect/system-design.md` with `solution-architect/` workspace artifacts across build.md, define.md, harden.md, ship.md, and SKILL.md re-anchoring table.
- **Receipt paths missing workspace prefix** — 7 receipt paths like `.orchestrator/receipts/T1-*.json` fixed to `Claude-Production-Grade-Suite/.orchestrator/receipts/T1-*.json` across define.md, build.md, harden.md, ship.md, sustain.md.
- **Post-wave task dependency IDs** — T7/T8 blocked by `T5, T6a, T6b` (Wave A analysis tasks) → `T5b, T6c, T6d` (Wave B execution tasks). T11/T12 blocked by `T9` → `T9, T10` (T10 auto-completes when skipped).
- **Security engineer auto-fixing code in HARDEN** — removed "Auto-fix Critical/High issues" from T6a prompt. Security writes findings only; T8 Remediation handles fixes in SHIP phase to prevent merge conflicts with parallel QA agents.
- **Security findings paths** — replaced `security-engineer/findings/critical.md`, `findings/high.md` with actual output directories (`code-audit/`, `auth-review/`, `remediation/`) across harden.md, ship.md, and SKILL.md.
- **DevOps workspace path** — `devops/containers/` → `devops/` in SKILL.md context bridging table and build.md T4 prompt.
- **`multiSelect: False` (Python bool) in build.md** — changed to `false` (JSON bool).
- **QA agent count** — `4 parallel Agents` → `5 parallel Agents` (unit, integration, contract, e2e, performance).
- **Code reviewer agent count** — `3 parallel Agents` → `4 parallel Agents` (arch conformance, code quality, performance, test quality).
- **PM output file list** — `research-notes.md, constraints.md` → `INDEX.md` in define.md.
- **SHIP re-verification ordering** — restructured ship.md: split single worktree merge-back section into PARALLEL #5 merge → re-verification → PARALLEL #6 → PARALLEL #6 merge. Previously re-verification ran after T9/T10 instead of between the two parallel pairs.
- **T10 auto-detection missing implementation** — added explicit Grep instruction with pattern, glob, and output_mode for LLM/ML import scanning.
- **TeammateIdle hook comment** — referenced `TeamDelete` as primary cleanup; updated to reference `pipeline-status` marker.
- **Auto-update temp path** — `/tmp/pg-update` → `$TMPDIR/pg-update` for sandbox compatibility.
- **Auto-update missing `hooks/`** — `cp -r` now includes `hooks/` directory alongside `skills/` and `.claude-plugin/`.

### Changed
- **Pipeline cleanup simplified** — removed `TeamDelete` from cleanup flow. Foreground agents terminate when their work returns to the orchestrator; the `pipeline-status` marker signals completion to the TeammateIdle hook.

## [5.7.1] — 2026-03-11

### Fixed
- **Gate 3 verification receipt gap** — ship.md expected verification receipts for Critical/High findings but no task re-scanned after remediation. Added re-verification step: after T8 completes, an opus agent re-scans affected files and writes `T8-verification.json`. Gate 3 now checks this receipt instead of requiring nonexistent per-finding receipts.
- **T4 plan file naming mismatch** — planner wrote `T4a-containers-plan.md` but task is T4 (not T4a). Renamed to `T4-containers-plan.md` across build.md and SKILL.md (6 references). Added fallback for when Model-Optimization is disabled and no planner runs.
- **False T9a comment in ship.md** — comment claimed "T9a (SLO definitions) ran during Wave A in BUILD phase" but no T9a task exists in any dispatcher. Replaced with accurate description: T9 handles the full SRE scope in SHIP.
- **Conflict resolution header** — "Feedback Loops (HARDEN → BUILD)" corrected to "HARDEN → SHIP Remediation" since remediation happens in T8 (SHIP phase).
- **Dead UserPromptSubmit hook config** — `activation-rules.json` defined a `hook_config` for `UserPromptSubmit` not wired in `hooks.json`. Marked with `"active": false` and `"status": "planned"` to prevent false expectations.
- **Worktree pre-flight indentation bug** — `if result.strip():` was at the outer indentation level in build.md, executing even when settings.md already had a worktree decision (referencing undefined `result`). Fixed indentation to nest inside the `else` block.
- **T3a/T3b merge-back positioned after T4** — build.md had a NOTE saying merge before T4 but the merge-back section was after the T4 Agent call. Added explicit "Merge T3a/T3b Worktree Branches Before T4" section positioned correctly before PARALLEL #2.
- **Duplicate step numbering in harden.md** — two consecutive items both numbered "2." in post-HARDEN processing. Fixed to sequential 2-7.
- **Technical writer soft dependency** — `03-developer-guides.md` referenced `qa-engineer/test-plan.md` without fallback. Added graceful degradation when QA has not run.

### Changed
- **Two-wave model note strengthened** — SKILL.md note now explicitly states which tasks each dispatcher actually executes (BUILD: T3a/T3b/T4, HARDEN: T5/T6a/T6b, SHIP: T7-T10) vs the theoretical two-wave model.
- **Worktree branch extraction documented** — all three phase dispatchers (build.md, harden.md, ship.md) now include guidance on how to parse branch names from Agent results.

## [5.7.0] — 2026-03-11

### Added
- **Planner-executor architecture** — opus wave planners produce file-level execution plans before parallel waves; sonnet agents execute against those plans without making architectural decisions. Wave A planner (BUILD) writes `T3a-backend-plan.md`, `T3b-frontend-plan.md`, `T4a-containers-plan.md`. SHIP planner writes `T7-infra-plan.md`, `T8-remediation-plan.md`. Plans include every file to create, every function signature, implementation steps, error handling — detailed enough that executors never need to make judgment calls. Plans stored in `Claude-Production-Grade-Suite/.orchestrator/plans/{wave}/`.
- **Model tier strategy** — per-agent model selection using the `model` parameter restored in Claude Code 2.1.72. Three roles: Planner (`opus` — wave planners), Analysis (`opus` — Security, Code Reviewer, SRE, Data Scientist, Skill Maker), Executor (`sonnet` — Backend, Frontend, DevOps, QA, Remediation, Tech Writer). Haiku excluded — all plugin tasks require either judgment (opus) or codebase understanding (sonnet). Tier assignments based on specs-vs-judgment analysis of all 14 skill SKILL.md files. Reduces full pipeline cost by ~30-50%. Enabled by default via `Model-Optimization: enabled` in settings.md. All 12 Agent calls across 4 phase dispatchers updated.
- **Effort symbol disambiguation** — visual-identity protocol now documents that `○ ◐ ●` also represent Claude Code 2.1.72+ effort levels (low/medium/high). No pipeline output conflict (different rendering contexts), but `◐` excluded from pipeline icons to avoid confusion.
- **Parallel tool failure resilience** — tool-efficiency protocol updated with new Rule 5: failed Read/WebFetch/Glob no longer cancel sibling tool calls (Claude Code 2.1.72 fix). Parallel discovery batches are now safe without defensive file-exists checks.

### Changed
- **Minimum Claude Code version** bumped to 2.1.72+ (from 2.1.69+). Required for model parameter, parallel resilience, and worktree fixes.
- **Settings schema** — `Model-Optimization: [enabled|disabled]` added to pipeline settings alongside Engagement, Parallelism, and Worktrees.
- **Common mistakes table** — 2 new entries: all agents running on Opus (use model tiers), omitting `model` when optimization enabled.

### Improved (from Claude Code 2.1.72 upstream)
- **Worktree isolation reliability** — Task tool resume now restores cwd correctly, background task notifications include `worktreePath` and `worktreeBranch`. Improves reliability of the existing foreground-agent worktree pattern.
- **Team model inheritance** — team agents now properly inherit the leader's model (fixed in 2.1.72). Combined with model tiers, this means: when Model-Optimization is disabled, all agents reliably inherit the leader's model; when enabled, per-agent overrides work correctly.
- **Skill hooks single-fire** — hooks no longer fire twice per event when a hooks-enabled skill is invoked by the model. The plugin's SessionStart and TeammateIdle hooks are more reliable.
- **CLAUDE.md HTML comments hidden** — HTML comments (`<!-- ... -->`) in CLAUDE.md are now hidden from auto-injection but visible via Read tool. The SUSTAIN phase's Production-Grade Native directive is unaffected (no HTML comments), but this opens a path for embedding pipeline metadata in CLAUDE.md comments.
- **Bash auto-approval additions** — `lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind` now auto-approved, reducing permission prompts for agents.
- **Prompt cache optimization** — SDK query() prompt cache fix reduces input token costs up to 12x, directly benefiting the plugin's multi-agent execution.

## [5.6.0] — 2026-03-09

### Fixed
- **Worktree changes lost on cleanup** — all parallel agent dispatches across BUILD, HARDEN, SHIP, and SUSTAIN phases used `run_in_background=True` with `isolation="worktree"`. Background agents caused the orchestrator turn to end before worktree merge-back could fire, so Claude Code auto-cleaned the worktrees and discarded agent output. Fix: all phase-level agents now run as foreground agents. Multiple foreground agents in the same message still execute concurrently — parallelism is preserved — but the orchestrator blocks until all return, ensuring merge-back and subsequent phases fire correctly.
- **SKILL.md dispatch examples taught the wrong pattern** — two code examples in the orchestrator SKILL.md showed `run_in_background=True` as the recommended Agent dispatch pattern. Updated to foreground dispatch with explanation of why concurrent foreground agents preserve both parallelism and execution chain integrity.

### Changed
- **BUILD Phase** — T3a + T3b now foreground (concurrent in same message). T4 starts after both complete and merge-back (previously documented as starting after T3a alone, which was unreliable with worktrees).
- **HARDEN Phase** — T5 + T6a + T6b now foreground (concurrent in same message).
- **SHIP Phase** — T7 + T8 (PARALLEL #5) and T9 + T10 (PARALLEL #6) now foreground (concurrent in same message per wave).
- **SUSTAIN Phase** — T11 + T12 already fixed in v5.5.1.

## [5.5.0] — 2026-03-08

### Added
- **Effort level auto-set** — session guard sets `CLAUDE_CODE_EFFORT_LEVEL=high` via `CLAUDE_ENV_FILE` for production-grade projects. Ensures Sonnet 4.6 and Opus 4.6 operate at full reasoning depth throughout the pipeline.
- **Compaction guard** — session guard detects active pipeline state and outputs a short re-orientation block instead of re-firing the full guard prompt during compaction or `/clear`. Prevents mid-pipeline disruption.
- **TeammateIdle hook** — new `teammate-idle-guard.sh` with pipeline-status marker check. Stops orphaned teammates when the pipeline completes or is rejected at a gate. Orchestrator writes `pipeline-status: complete|rejected` before calling `TeamDelete`.
- **Minimum Claude Code version** bumped to 2.1.69+.

### Changed
- **`${CLAUDE_SKILL_DIR}` adoption** — all phase file references across 7 skills with phases (42 references) converted from bare relative paths to `${CLAUDE_SKILL_DIR}/phases/...`. Zero bare paths remain. Ensures skills resolve correctly regardless of install location.
- **Author/repo references** updated to ulfsimonsen across plugin metadata and README.

### Fixed
- **SUSTAIN phase stall** — T11 + T12 ran as background agents, causing the orchestrator turn to end after dispatch. T13 (compound learning + final assembly) never fired. Fix: T11 + T12 now run as foreground agents (still concurrent in same message). Orchestrator blocks until both return, then naturally continues to T13.

## [5.4.0] — 2026-03-07

### Added
- **Harmonization protocol** — new Section 8 in DEV_PROTOCOL.md. Conflict matrix with 9 check categories, 7-level authority hierarchy (VISION > DEV_PROTOCOL > Protocols > Orchestrator > Phase dispatchers > Sub-skill SKILL.md > Agent() prompts), recurring audit triggers, and harmonization checklist. Ensures cohesiveness as the system evolves.
- **Pipeline gates vs agent questions distinction** — formalized in VISION.md Principle IV and DEV_PROTOCOL. Pipeline gates (3 per run: BRD, Architecture, Production Readiness) are mode-independent. Agent questions (framework choice, style selection, test strategy) scale with engagement mode: zero in Express, full in Meticulous. An agent question firing in Express mode is now defined as a design bug.
- **Cross-session enforcement via SessionStart hook** — new `hooks/hooks.json` and `hooks/session-guard.sh`. Detects projects built with production-grade (via `Claude-Production-Grade-Suite/` directory) and presents a courteous 3-option choice: use production-grade, work directly, or chat about it. Silent in non-production-grade projects.
- **SUSTAIN phase CLAUDE.md directive** — production-grade native projects get a CLAUDE.md section prompting the 3-option choice at session start, ensuring cross-session consistency.

### Changed
- **Mode-aware AskUserQuestion across all skills** — 15+ mandatory user prompts across 11 files converted from "always ask" to engagement-mode-aware behavior. Express auto-resolves with sensible defaults and reports choices. Standard asks only subjective/irreversible decisions (1-2 per skill). Thorough surfaces all major decisions. Meticulous surfaces every decision point.
- **UX Protocol Rule 6** rewritten as engagement-mode-aware autonomy spectrum with explicit table (Express/Standard/Thorough/Meticulous behaviors) plus "never mode-dependent" and "always mode-dependent" lists.
- **Frontend Engineer** — style selection (Creative/Elegance/High Tech/Corporate) now mode-aware: Express auto-selects based on domain mapping, Standard+ asks user. Framework confirmation, page approval, and design review all mode-aware.
- **Software Engineer** — context analysis clarifications, plan review, service implementation review, and integration review all mode-aware.
- **DevOps** — 6-question infrastructure interview now mode-aware: Express infers from code, Standard asks unknowns, Thorough/Meticulous full interview.
- **Security Engineer** — compliance/threat context questions mode-aware: Express infers from domain, Standard asks compliance only.
- **Skill Maker** — Phase 1 interview mode-aware: Express skips entirely, Standard 1-2 questions.
- **Technical Writer** — content audit approval and deployment options mode-aware: Express defaults to GitHub Pages.
- **All Agent() prompts in phase dispatchers** — now include explicit `Use the Skill tool to invoke 'production-grade:<skill-name>'` instruction, ensuring sub-agents load their full SKILL.md methodology instead of flying blind with 5-10 line prompts.
- **VISION.md** — fixed all numeric references: "Thirteen" → "Fourteen" agents (4 occurrences), "13 skills" → "14 agents", "original 13" → "built-in 14".
- **DEV_PROTOCOL.md** — fixed "10 principles" → "11 principles". Added 3 new quality checklist items (mode-awareness, numeric consistency, Agent() prompt alignment).

## [5.3.0] — 2026-03-07

### Added
- **Worktree isolation for parallel agents** — all parallel Agent calls now use `isolation="worktree"` by default. Each concurrent agent gets its own git worktree — zero file race conditions. Dirty-state detection with auto-commit or fallback option. Merge-back orchestration after each wave completes. Worktree decision stored in pipeline settings.
- **Self-healing gates (rework loops)** — gate rejection no longer stops the pipeline. When a user rejects at Gate 2 or Gate 3, concerns are fed back to the relevant agent (Solution Architect or Remediation Engineer) for rework. Re-verification and re-presentation happen automatically. Max 2 rework cycles per gate before escalation. All rework cycles logged to `.orchestrator/rework-log.md` with concerns and changes.
- **Cost dashboard** — effort tracking in every receipt (`files_read`, `files_written`, `tool_calls`). Pre-pipeline cost estimate shown after engagement mode selection (based on mode × engagement × project complexity). Final summary includes aggregated cost metrics across all agents with estimated token usage.
- **Cost estimation table** in visual-identity protocol — lookup table for estimated tokens by mode (Full Build, Feature, Harden, etc.) × engagement level (Express through Meticulous).

### Changed
- **Receipt protocol** — new `effort` field added to receipt schema (files_read, files_written, tool_calls). All agent prompts in phase dispatchers updated to include effort tracking.
- **All 5 phase dispatchers** (define, build, harden, ship, sustain) — Agent calls include `isolation="worktree"`, worktree pre-flight check in BUILD, merge-back instructions after each parallel wave.
- **Orchestrator parallelism preference** — new "Maximum + worktree isolation" option (recommended default). Settings now include `Worktrees: enabled|disabled`.
- **Gate 2 ceremony** — "I have concerns" replaced with "Rework architecture" with explicit rework loop.
- **Gate 3 ceremony** — "Fix issues first" replaced with "Rework — fix issues first" with remediation re-run and re-verification.
- **Final summary template** — new cost line showing agents used, total tool calls, files processed, estimated tokens. Worktree and rework cycle counts included.
- **DEV_PROTOCOL.md** — 3 new differentiators (worktree isolation, self-healing gates, cost dashboard). 3 new common quality failure entries. Cost estimation marked as shipped.

## [5.2.0] — 2026-03-07

### Added
- **Frontend "make it work, then make it beautiful" overhaul** — restructured from 5 to 6 phases. Phase 2 reduced to functional defaults (system fonts, neutral palette — move fast). NEW Phase 5 (Design & Polish) added after functional verification.
- **4 visual style presets** — user selects Creative, Elegance, High Tech, or Corporate at the start of Phase 5. Each drives all design decisions: colors, typography, spacing, interaction richness, dark mode treatment.
  - **Creative** — vibrant, bold gradients, expressive fonts, animated transitions, illustrated empty states
  - **Elegance** — minimalist, Apple-inspired, restrained palette, thin font weights, whitespace-driven
  - **High Tech** — terminal aesthetics, monospace accents, dark-mode-first, data-dense, grid-aligned
  - **Corporate** — formal, conservative palette, standard layouts, no animations, enterprise-ready
- **Design research phase** — Phase 5 uses WebSearch (freshness protocol) to research domain trends, competitive visual benchmarks, and style-specific inspiration before making any design decisions.
- **Frontend functional completeness enforcement** — Phase 4b (Functional Verification Pass). Dead Element Rule: any button/link/form that renders but does nothing is a Critical bug. Navigation Graph Verification. Interaction Trace: top 5 user flows walked click-by-click. Cross-Agent Reconciliation after parallel page builds.

### Changed
- **Frontend Engineer** — 6 phases (was 5). Phase 2 is functional defaults. Phase 5 is design research + polish. Phase 6 (Testing) tests the final polished version.
- **Code Reviewer** Phase 2 — new checks for dead interactive elements and navigation completeness.

## [5.1.0] — 2026-03-07

### Added
- **Boundary safety protocol** — new shared protocol (`boundary-safety.md`) with 6 structural patterns that cause silent failures at system boundaries. Derived from real deployment bugs found during a production-grade pipeline run on PingBase.
- **6 patterns enforced**: (1) framework abstractions break at boundaries — use platform primitives when crossing domains, (2) delegate to framework control flow — don't duplicate middleware logic in UI, (3) self-referencing config creates infinite loops, (4) global interceptors must be conditional, (5) test full user journeys across system boundaries, (6) identity must be consistent across integrated systems.

### Changed
- **All 14 skills** now load `boundary-safety.md` at startup.
- **Frontend Engineer** — 7 new Common Mistakes entries for navigation misuse, auth flow duplication, callback misconfiguration, and unconditional interceptors.
- **Code Reviewer** Phase 2 — new "Boundary Safety" review dimension (5 checks): framework abstraction misuse, duplicated control flow, self-referencing config, unconditional interceptors, identity consistency.
- **QA Engineer** Phase 5 (E2E) — 2 new rules requiring cross-boundary journey testing and framework navigation correctness verification. 2 new Common Mistakes entries.
- **Orchestrator** Common Mistakes table expanded with 4 boundary safety anti-patterns.
- **Orchestrator** protocol table updated to include `boundary-safety.md`.

## [5.0.0] — 2026-03-06

### Added
- **Receipt-based gate enforcement** — new shared protocol (`receipt-protocol.md`) requiring every agent to write a JSON receipt as proof of completion. Receipts list artifacts produced, concrete metrics, and verification summary. Orchestrator verifies receipts and artifact existence at every phase transition and before every gate. No receipt = task not complete.
- **Receipt verification at all 3 gates** — Gate 1 verifies PM receipt, Gate 2 verifies Architect receipt, Gate 3 verifies ALL receipts including remediation chain (finding → fix → verification) for Critical/High issues.
- **Remediation receipt chain** — Critical/High findings require three receipts: finding agent receipt, remediation receipt, and verification receipt from the original finder confirming the fix. All three must exist before Gate 3 opens.
- **Re-anchoring protocol** — orchestrator re-reads key workspace artifacts FROM DISK at every phase transition (DEFINE→BUILD, BUILD→HARDEN, HARDEN→SHIP, SHIP→SUSTAIN). Prevents context drift in long pipeline runs where compressed memory degrades accuracy of specs, ADRs, and API contracts.
- **Adversarial code review stance** — code-reviewer skill reframed from neutral observer to adversarial challenger. Assumes code is wrong until proven right. Scaled with engagement mode: Express (Critical-only hunt), Standard (Critical+High), Thorough (all severities with edge case analysis), Meticulous (hostile with reproducible break scenarios).
- **Phase-specific adversarial framing** — each review phase (Architecture Conformance, Code Quality, Performance, Test Quality) has explicit adversarial framing directing the reviewer to assume violations exist.

### Changed
- **All 14 skills** now load `receipt-protocol.md` at startup.
- **All 5 phase dispatchers** updated with receipt verification blocks, re-anchor blocks, and receipt-writing instructions in agent prompts.
- **Orchestrator bootstrap** creates `.orchestrator/receipts/` directory.
- **Gate ceremony templates** now read verified receipt data for metrics display instead of relying on agent memory.
- **Non-Full-Build modes** write and verify receipts at mode completion.
- **Common Mistakes table** expanded with receipt, re-anchoring, and adversarial review anti-patterns.

## [4.4.0] — 2026-03-06

### Added
- **Freshness protocol** — new shared protocol (`freshness-protocol.md`) that gives all 14 agents temporal sensitivity to volatile data. Agents now recognize when they're about to use potentially outdated information (LLM model IDs, API pricing, package versions, CVEs, framework APIs, Docker tags, cloud service features) and trigger WebSearch to verify before implementing.
- **4-tier volatility classification** — Critical (days-weeks: model IDs, pricing, CVEs → MUST search), High (weeks-months: package versions, framework APIs, Docker tags → search when writing config), Medium (months-quarters: browser APIs, crypto best practices → search if uncertain), Stable (years+: language fundamentals, protocols → trust training data).
- **Search-then-implement pattern** — when volatile data is detected, agents pause, WebSearch for current state, cite what they found with `✓ Verified:` markers, then implement with verified data.
- **Skill-specific sensitivity table** — each agent knows its own high-sensitivity areas (Software Engineer: package versions/SDK APIs, DevOps: Docker tags/Terraform providers, Security: CVEs/crypto, Data Scientist: LLM model IDs/pricing, etc.).

### Changed
- **All 14 skills** now load `freshness-protocol.md` at startup alongside existing protocols.
- **Orchestrator protocol table** updated to include freshness protocol in workspace bootstrap.

### Fixed
- **Orphaned agents after pipeline completion** — orchestrator now calls `TeamDelete` after the final summary and on gate rejection. Previously, all agents remained idle indefinitely after work was done, requiring manual intervention to shut down.

## [4.3.0] — 2026-03-06

### Added
- **Visual identity protocol** — new shared protocol (`visual-identity.md`) defining the complete design language: sleek, elegant, high-tech aesthetic. Container hierarchy (Tier 1 double-line for key moments, Tier 2 single-line for data grids, Tier 3 heavy rules for section headers). Standardized icon vocabulary (`◆ ⬥ ● ○ ✓ ✗ ⧖ ⚠ →`). No emoji — Unicode symbols only for monospace alignment.
- **Pipeline dashboard** — `╔═══╗` status board printed at kickoff and every phase transition. Shows all 5 phases with status (`○ pending` → `● active` → `✓ complete`), elapsed time per phase, and total elapsed time. The dashboard re-rendering IS the progress animation.
- **Gate ceremonies** — visual framing before each approval gate. Prints concrete metrics block (key-value pairs with numbers) between `━━━` rules with `⬥ GATE N` header and elapsed time. Gives decision moments visual weight and authority.
- **Wave announcements** — Tier 2 boxes showing all agents in a parallel wave on launch, then checkmark cascade with concrete metrics on completion. Peak visual moment: rapid `✓` lines with per-agent results.
- **Transition announcements** — `→` prefixed lines between phases and waves explaining what's next. Eliminates "what's happening?" anxiety.
- **Numbered phase progress** — every skill prints `[1/N]` phase progress with `✓`/`⧖`/`○` step indicators and concrete counts. Users always know where each skill is in its work.
- **Concrete completion summaries** — every agent completion line MUST include numbers. `✓ Security Engineer    12 findings (2 Critical, 3 High, 7 Medium)` not `✓ Security Engineer — complete`.
- **Before→after deltas** — `12 findings → 0 Critical remaining`, `0% → 94% coverage`. Proves transformation happened.
- **Findings severity grid** — structured display with Critical/High detail, Medium/Low counts, dedup total.
- **Elapsed timing** — tracked at 3 levels: total pipeline, per-phase, per-wave. Not per-step (too granular).
- **Streaming as animation** — documented that Claude's token-by-token streaming IS our animation channel. Visual blocks designed for progressive reveal consumption.

### Changed
- **UX Protocol Rule 5** updated to reference visual identity protocol with concrete formatting requirements.
- **Orchestrator kickoff** replaced bare `━━━` banner with full pipeline dashboard.
- **All 3 gate templates** upgraded with ceremony framing (metrics block + `⬥` header).
- **Final summary** expanded from compact box to detailed per-phase breakdown with bottom-line stats (agents used, tasks completed, files created, tests passing, vulnerabilities remaining).
- **All 5 phase dispatchers** updated with visual output sections: phase banners, wave start/completion templates, transition announcements.
- **All 13 sub-skills** updated with visual-identity protocol loading, numbered phase progress patterns, and structured completion summaries.
- **Upgraded findings summary** in HARDEN phase from simple `✓` list to severity grid with critical finding details.

## [4.2.0] — 2026-03-06

### Added
- **Adaptive routing** — orchestrator now analyzes the user's request and routes to the right skills automatically. No longer requires full pipeline for every task.
- **10 execution modes**: Full Build, Feature, Harden, Ship, Test, Review, Architect, Document, Explore, Optimize, Custom. Each with appropriate skill composition, gates, and parallelism.
- **Request classification** — automatic intent detection maps user requests to modes. "Add auth to my API" → Feature mode (PM + Architect + Backend + QA). "Review my code" → Review mode (Code Reviewer only).
- **Execution plan presentation** — user sees which skills will run and can adjust, escalate to full pipeline, or proceed.
- **Custom mode** — multi-select skill menu for requests that don't fit standard patterns.
- **Lightweight mode execution** — non-Full-Build modes skip unnecessary overhead (engagement/parallelism prompts only for 3+ skill modes).

### Changed
- Plugin description broadened from "build a complete production-ready system" to "any software engineering work that benefits from structured, production-quality execution."
- "When to Use" expanded to cover: adding features, hardening, deploying, testing, reviewing, documenting, optimizing, exploring — not just greenfield builds.
- Full Build pipeline preserved unchanged as one mode within the adaptive orchestrator.

## [4.1.0] — 2026-03-05

### Added
- **Engagement modes** — 4-level interaction depth (Express, Standard, Thorough, Meticulous) chosen at pipeline start. Controls PM interview depth, architect discovery depth, and phase summary visibility. Persisted in `Claude-Production-Grade-Suite/.orchestrator/settings.md`.
- **Architecture Fitness Function** — Solution Architect now DERIVES architecture from constraints instead of picking templates. Scale, team size, budget, compliance, data patterns, geographic distribution, growth model, and uptime SLA all feed into architecture decisions. A 100-user internal tool gets a monolith; a 10M-user platform gets microservices.
- **Scale & Fitness Interview** — Adaptive 1-4 round interview (depth scales with engagement mode). Covers: users, CCU, data patterns, team size, budget, compliance, latency, uptime SLA, geographic distribution, growth model, vendor strategy, extensibility.
- **Adaptive PM interview** — Express: 2-3 questions. Standard: 3-5. Thorough: 5-8 with competitive analysis. Meticulous: 8-12 across multiple rounds with co-authored acceptance criteria.

### Changed
- **Engagement mode propagated to ALL 14 skills** — every agent reads `settings.md` and adapts decision surfacing. Express: fully autonomous. Standard: surface 1-2 critical decisions. Thorough: surface all major decisions. Meticulous: surface every decision point.
- Solution Architect Phase 1 rewritten from 5 shallow questions to a comprehensive adaptive discovery process with structured AskUserQuestion options at every step.
- Product Manager Phase 1 rewritten with 4 interview depth profiles matching engagement modes.
- Pipeline kickoff now asks engagement mode before parallelism preference (step 5, renumbered to 11 total steps).
- **Software Engineer parallelism revised** — shared foundations (libs/shared: types, errors, middleware, auth, logging, config) established SEQUENTIALLY before parallel service agents. Each service agent reads shared foundations. Prevents N different error handling/auth implementations.
- **Frontend Engineer parallelism revised** — UI Primitives built SEQUENTIALLY first (foundational atoms), then Layout + Feature components in PARALLEL (both import from primitives). Prevents duplicate Button/Input implementations.
- Orchestrator internal skill parallelism table updated to reflect foundations-first pattern.

## [4.0.0] — 2026-03-05

### Changed
- **Two-wave parallel execution** — orchestrator splits work into Wave A (build + analysis in parallel) and Wave B (execution against code in parallel). Analysis tasks (QA test plan, STRIDE threat model, SLO definitions, arch conformance checklist) start alongside build instead of waiting for code. Up to 7+ concurrent agents in Wave A, 4+ in Wave B.
- **Internal skill parallelism** — 8 skills now spawn parallel Agents for independent work units: software-engineer (1 agent per service), frontend-engineer (1 agent per page group), qa-engineer (unit/integration/e2e/performance in parallel), security-engineer (code audit/auth/data/supply chain in parallel), code-reviewer (arch/quality/performance in parallel), devops (IaC/CI-CD/containers in parallel), sre (chaos/incidents/capacity in parallel), technical-writer (API ref/dev guides in parallel).
- **Dynamic task generation** — orchestrator reads architecture output (number of services, pages, modules) and creates tasks accordingly. No hardcoded task count.

### Added
- **Parallelism preference** — user selects performance mode at pipeline start: Maximum (recommended), Standard, or Sequential. No config file needed.
- **Token economics** — parallel execution is both faster AND cheaper. Each agent carries minimal context instead of accumulating prior work. ~45% fewer total input tokens for 3+ services.

## [3.3.0] — 2026-03-05

### Added
- **Brownfield awareness** — orchestrator detects greenfield vs existing codebase at startup. Scans for source files, frameworks, and infrastructure. Generates `.production-grade.yaml` from discovered structure. Writes `codebase-context.md` with safety rules for all agents.
- **Codebase discovery** — parallel scan of project root for package.json, go.mod, pyproject.toml, existing src/, services/, frontend/, tests/, Dockerfiles, CI configs.
- All 8 BUILD/SHIP skills (software-engineer, frontend-engineer, devops, qa-engineer, solution-architect, sre, technical-writer, and orchestrator) now load brownfield context and follow "never overwrite, extend don't replace" rules.

### Changed
- **MECE intent-based skill routing** — all 14 skill descriptions rewritten from keyword triggers to intent descriptions. Each skill has a unique precondition and domain. No overlap.

### Fixed
- **Protocol loading crash** — all 13 sub-skills crashed on load when protocol files didn't exist. Added `|| true` fallback.
- **Polymath priority** — uncertainty expressions now correctly route to polymath before product-manager.

## [3.2.0] — 2026-03-05

### Added
- **Auto-update with consent** — orchestrator checks for new versions on pipeline start, prompts user only when update is available. Silent if current, graceful fallback if offline.
- Dynamic version display in pipeline banner and completion summary.

### Fixed
- **Protocol loading crash** — all 13 sub-skills crashed on load when protocol files didn't exist yet. Added `|| true` fallback to all `cat` commands.
- **MECE intent-based skill routing** — replaced keyword trigger matching with intent descriptions across all 14 skills. Each skill now describes user state and domain, not trigger phrases. Polymath correctly activates on uncertainty signals instead of losing to keyword matches.
- **Polymath priority** — uncertainty expressions ("don't know where to start", "not sure how") now correctly route to polymath before product-manager or production-grade.

## [3.1.0] — 2026-03-05

### Added
- **Polymath co-pilot** — the 14th skill. Thinks with you before, during, and after the pipeline.
- 6 Polymath modes: onboard, research, ideate, advise, translate, synthesize.
- Pre-flight gap detection — orchestrator detects knowledge gaps and invokes Polymath before proceeding.
- Gate companion — "Chat about this" at any approval gate routes to Polymath for plain-language explanation.
- Product Manager integration — PM reads Polymath context package to shorten CEO interview.

### Changed
- README rewritten as concise marketing material with GitHub badges, Star History, and Quick Start near top.

## [3.0.0] — 2026-03-04

### Changed
- **Full rewrite** — Teams/TaskList orchestration replaces custom state management.
- 7 parallel execution points across the pipeline.
- 4 shared protocols: UX, input validation, tool efficiency, conflict resolution.
- Large skills split into router + on-demand phases for 65% token savings.
- Sole-authority conflict resolution: security-engineer owns OWASP, SRE owns SLOs.

### Added
- Phase-based skill splitting: software-engineer (5), frontend-engineer (5), security-engineer (6), SRE (5), data-scientist (6), technical-writer (4).
- Conditional task execution: frontend auto-skip, data-scientist auto-detect.
- Partial execution: "just define", "just build", "just harden", "just ship", "just document".

## [2.0.0] — 2026-03-04

### Changed
- **Bundle all 13 skills** into a single plugin install.
- Unified workspace architecture: deliverables at project root, workspace artifacts in `Claude-Production-Grade-Suite/`.
- Prescriptive UX Protocol enforced across all skills: AskUserQuestion with options only, never open-ended.

### Added
- Skill Maker as pipeline phase for generating project-specific custom skills.
- VISION.md: ten principles governing the ecosystem.

## [1.0.0] — 2026-03-03

### Added
- Initial release: production-grade orchestrator plugin.
- 12 specialized agent skills coordinated through dependency graph.
- 3 approval gates, autonomous execution between gates.
- DEFINE > BUILD > HARDEN > SHIP > SUSTAIN pipeline.
