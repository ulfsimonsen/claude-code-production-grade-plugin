# ADR-001: Self-Improvement Mode Architecture

**Status:** Accepted
**Context:** US-13 requires a new "Improve" execution mode (12th mode) that focuses on a single agent, skill, or agent+skill pair and iterates on its DEFINITION (SKILL.md, phase files, prompts) until a score threshold is met or time runs out.

**Decision:** Dedicated evaluator agent with Python-backed scoring, time-bounded composite termination, and meta-improvement of agent/skill definitions.

## Architecture

### Components

1. **Loop Orchestrator** (`skills/production-grade/phases/improve.md`)
   - New phase dispatcher for Improve mode
   - Manages iteration lifecycle: spawn target → evaluate → feedback → modify definition → repeat
   - Tracks termination conditions: `TIME`, `THRESHOLD`, `MAX_ITERATIONS`, `MAX_EVALUATIONS`
   - Uses `SendMessage(to: agentId)` to continue agents across iterations
   - Uses `CronCreate` for time-bounded execution (long-running "run for 8 hours" scenarios)
   - Stores iteration history in `Claude-Production-Grade-Suite/.orchestrator/iterations/`

2. **Evaluator Agent** (`skills/evaluator/SKILL.md`)
   - 15th skill, NOT part of the pipeline's 14-agent roster
   - Receives: rubric (binary criteria + weights), target agent's output reference
   - Checks each criterion → pass/fail → computes weighted score
   - Uses Python utility scripts for deterministic checks (regex, AST, test execution, linting)
   - LLM judgment reserved for criteria that can't be automated
   - Returns: score vector, feedback per failed criterion, overall score percentage
   - Extractable as standalone project (no hard dependency on pipeline infrastructure)

3. **Score Function Definition** (`Claude-Production-Grade-Suite/.orchestrator/score-function.md`)
   - User-defined rubric: list of binary criteria with optional weights
   - Defined via Elicitation at Improve mode start
   - Threshold and termination conditions stored alongside

4. **Target Agent/Skill**
   - Any of the 14 agents, any user-defined skill, or an agent+skill pair
   - Runs against a target (existing codebase, test project, sample data)
   - Its SKILL.md / phase files ARE the artifact being improved across iterations

### What Gets Improved

The improvement loop modifies the **agent/skill definition files** (SKILL.md, phases/*.md, prompts). This is meta-improvement — the instructions themselves evolve. Python utility scripts are created opportunistically when the evaluator determines they'd improve the agent's score.

### Iteration Flow

```
1. User defines: target (agent/skill), rubric (binary criteria), termination (TIME/THRESHOLD/MAX_ITERATIONS/MAX_EVALUATIONS)
2. Snapshot current SKILL.md as iteration-0 baseline
3. Target agent runs against evaluation target
4. Evaluator scores output against rubric
5. If score >= THRESHOLD or termination condition met → STOP, keep best-scoring definition
6. Evaluator produces feedback: which criteria failed, why, suggestions
7. Orchestrator modifies SKILL.md / phase files based on feedback
8. Python utility scripts created/modified IF evaluator determines they'd help
9. GOTO 3
```

### Termination Conditions (Composite, All Optional)

| Condition | Type | Default | Description |
|-----------|------|---------|-------------|
| `TIME` | duration | none | Wall-clock limit. "Run for 1 hour." |
| `THRESHOLD` | percentage | 90% | Score target. Stop when met. |
| `MAX_ITERATIONS` | integer | 5 | Maximum improve cycles. |
| `MAX_EVALUATIONS` | integer | 10 | Maximum evaluation runs. |

Any condition triggers stop. Combinable: `TIME=2h AND THRESHOLD=95%` means "run for up to 2 hours, stop early if 95% reached."

### Python Scripts Role

- **Not the main artifact** — SKILL.md definitions are the main artifact
- **Utility scripts** created when the evaluator determines they'd improve the score
- Created, modified, and deleted as part of the iteration process
- Examples: custom linter rules, test harnesses, AST analyzers, output validators
- The evaluator itself uses Python scripts for consistent, deterministic criterion checking
- Stored in `Claude-Production-Grade-Suite/evaluator/scripts/`

### Extractability

The evaluator agent (`skills/evaluator/`) must be extractable as a standalone project:
- No imports of pipeline-specific protocols (UX, visual identity, receipts)
- Score function format is self-contained JSON/markdown
- Python scripts have no dependencies on Claude-Production-Grade-Suite structure
- Evaluator reads rubric + output path, returns score vector — pure function

**Consequences:**
- Adds a 15th skill (evaluator) but it's NOT part of the 14-agent pipeline roster — it's Improve-mode-only
- SKILL.md frontmatter gains `improvable: true/false` flag for agents that opt into meta-improvement
- Version control of SKILL.md iterations becomes important — each iteration is git-committed for rollback
- Long-running TIME-based loops require Cron integration (US-4) for persistence across sessions

**Alternatives Considered:**
- Inline evaluation (agent scores itself): Rejected — bias risk, not extractable
- Orchestrator as evaluator: Rejected — not extractable as standalone, conflates concerns
