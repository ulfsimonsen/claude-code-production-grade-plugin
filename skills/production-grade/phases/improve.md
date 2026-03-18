# IMPROVE Phase — Dispatcher

This phase manages the Improve mode iteration loop: scope selection, score function definition, iterative target execution, evaluation, and definition refinement. No waves, no pipeline gates, no receipts. Improve mode has its own termination model.

## Mode Classification

Improve mode activates when the user's request matches these signals:

| Signal | Examples |
|--------|----------|
| `improve` | "improve the code-reviewer skill" |
| `iterate` | "iterate on the solution-architect until it's better" |
| `refine` | "refine the QA engineer prompt" |
| `optimize [single thing]` | "optimize the security-engineer skill" — scoped to ONE target |
| `self-improve` | "self-improve the product-manager" |
| `loop until better` | "loop the data-scientist until test pass rate hits 90%" |

**Important:** "optimize the whole pipeline" is NOT Improve mode — that is a Build/Harden concern. Improve mode is always scoped to ONE target.

## Visual Output

Print on start:

```
  → Starting IMPROVE phase
```

Print iteration progress throughout (see Iteration Loop section).

Print on completion:

```
  → IMPROVE complete — best score: {N}% retained
```

## Pre-Flight

Read `.production-grade.yaml` for path overrides:
- `paths.evaluator_scripts` → utility scripts location (default: `Claude-Production-Grade-Suite/evaluator/scripts/`)
- `paths.iterations` → iteration history location (default: `Claude-Production-Grade-Suite/.orchestrator/iterations/`)

Read `Claude-Production-Grade-Suite/.orchestrator/settings.md` for engagement mode. Improve mode respects `thorough` engagement for scope elicitation depth.

## Step 1: Scope Selection

Elicit the improvement target from the user. Offer exactly three scope options:

```python
Elicitation(questions=[{
  "question": "What do you want to improve?",
  "header": "Improve Mode: Target Selection",
  "options": [
    {"label": "Single agent (one SKILL.md)", "description": "Improve one agent's definition — e.g., code-reviewer, qa-engineer"},
    {"label": "Single skill (one custom skill)", "description": "Improve a user-defined skill's SKILL.md"},
    {"label": "Agent + skill pair", "description": "Improve both an agent and a skill together, evaluated as a unit"},
    {"label": "Chat about this", "description": "Free-form input about what to improve"}
  ],
  "multiSelect": false
}])
```

After scope type selection, ask which specific agent/skill:

```python
Elicitation(questions=[{
  "question": "Which agent or skill? (name or path)",
  "header": "Improve Mode: Target Name",
  "options": [
    # Built-in agents:
    {"label": "product-manager", "description": "skills/product-manager/"},
    {"label": "solution-architect", "description": "skills/solution-architect/"},
    {"label": "software-engineer", "description": "skills/software-engineer/"},
    {"label": "code-reviewer", "description": "skills/code-reviewer/"},
    {"label": "qa-engineer", "description": "skills/qa-engineer/"},
    {"label": "security-engineer", "description": "skills/security-engineer/"},
    {"label": "devops", "description": "skills/devops/"},
    {"label": "sre", "description": "skills/sre/"},
    {"label": "data-scientist", "description": "skills/data-scientist/"},
    {"label": "frontend-engineer", "description": "skills/frontend-engineer/"},
    {"label": "technical-writer", "description": "skills/technical-writer/"},
    {"label": "polymath", "description": "skills/polymath/"},
    {"label": "skill-maker", "description": "skills/skill-maker/"},
    {"label": "Other / custom path", "description": "Enter a custom skill path"}
  ],
  "multiSelect": false
}])
```

Ask for the evaluation target (what the agent/skill will run against):

```python
Elicitation(questions=[{
  "question": "What should the agent/skill run against for evaluation?",
  "header": "Improve Mode: Evaluation Target",
  "options": [
    {"label": "Current project (working directory)", "description": "Run against the files in this project"},
    {"label": "Sample data directory", "description": "Specify a directory path"},
    {"label": "Test fixture", "description": "Specify a test fixture path"},
    {"label": "Describe it", "description": "Free-form description of the evaluation target"}
  ],
  "multiSelect": false
}])
```

Store selections as:

```
improve_target:
  type: agent | skill | agent+skill
  agent: <name>            # if applicable
  skill: <name or path>   # if applicable
  definition_file: <path to SKILL.md>
  evaluation_target: <path or description>
```

## Step 2: Score Function Definition

Elicit the rubric: binary criteria with optional weights, plus threshold and termination conditions.

### Criteria

```python
Elicitation(questions=[{
  "question": "What criteria define 'better' for this agent/skill? Select all that apply.",
  "header": "Improve Mode: Score Function",
  "options": [
    {"label": "Test pass rate", "description": "% of tests passing. Specify threshold (e.g., >= 95%)"},
    {"label": "Code coverage %", "description": "Line/branch coverage. Specify threshold"},
    {"label": "Lint score", "description": "Zero lint errors, or score above threshold"},
    {"label": "Security findings", "description": "Zero high/critical findings from security scan"},
    {"label": "Output completeness", "description": "All required sections/artifacts present"},
    {"label": "No TODO/FIXME remaining", "description": "No unresolved placeholders in output"},
    {"label": "Custom LLM judge", "description": "Semantic quality criterion evaluated by LLM"},
    {"label": "Custom — describe it", "description": "Free-form criterion description"}
  ],
  "multiSelect": true
}])
```

For each selected criterion, ask for specifics (threshold values, patterns, etc.) as needed.

### Weights

Ask if any criteria should be weighted higher:

```python
Elicitation(questions=[{
  "question": "Should any criteria count more than others?",
  "header": "Improve Mode: Criterion Weights",
  "options": [
    {"label": "Equal weight — all criteria count the same (Recommended)", "description": "Simple average"},
    {"label": "Specify weights", "description": "Assign relative importance (1x, 2x, 3x) per criterion"}
  ],
  "multiSelect": false
}])
```

### Threshold

```python
Elicitation(questions=[{
  "question": "What overall score counts as 'good enough' to stop iterating?",
  "header": "Improve Mode: Threshold",
  "options": [
    {"label": "90% (Recommended)", "description": "Stop when weighted score reaches 90%"},
    {"label": "80%", "description": "More lenient — stop at 80%"},
    {"label": "95%", "description": "Strict — stop at 95%"},
    {"label": "100%", "description": "All criteria must pass"},
    {"label": "Custom threshold", "description": "Enter a specific percentage"}
  ],
  "multiSelect": false
}])
```

### Termination Conditions

```python
Elicitation(questions=[{
  "question": "When should the improvement loop stop? (combinable — all apply)",
  "header": "Improve Mode: Termination Conditions",
  "options": [
    {"label": "MAX_ITERATIONS: 5 (Recommended)", "description": "Stop after 5 improvement cycles"},
    {"label": "MAX_ITERATIONS: 3", "description": "Faster — 3 cycles maximum"},
    {"label": "MAX_ITERATIONS: 10", "description": "More thorough — 10 cycles maximum"},
    {"label": "TIME: 30 minutes", "description": "Run for up to 30 minutes"},
    {"label": "TIME: 1 hour", "description": "Run for up to 1 hour"},
    {"label": "TIME: 8 hours (async via Cron)", "description": "Long-running — uses CronCreate for persistence"},
    {"label": "MAX_EVALUATIONS: 10", "description": "Stop after 10 total evaluation runs"},
    {"label": "THRESHOLD only", "description": "Run until score target hit, no iteration cap"}
  ],
  "multiSelect": true
}])
```

Store the complete score function:

```markdown
<!-- Claude-Production-Grade-Suite/.orchestrator/score-function.md -->
# Score Function

target: <agent/skill name>
threshold: <N>%
criteria:
  - id: C1
    description: "<criterion>"
    weight: <N>
  - id: C2
    ...

termination:
  max_iterations: <N>     # optional
  max_evaluations: <N>    # optional
  time_limit: <duration>  # optional — "30m", "1h", "8h"
```

Write this to `Claude-Production-Grade-Suite/.orchestrator/score-function.md`.

## Step 3: Baseline Snapshot

Before the first iteration, snapshot the current definition:

```python
# Commit current SKILL.md as iteration-0 baseline
Bash("git add <definition_file> && git commit -m 'improve: iteration-0 baseline for <target>'")

# Write iteration-0 record
Write("Claude-Production-Grade-Suite/.orchestrator/iterations/iteration-0.json", json.dumps({
  "iteration_number": 0,
  "score_percentage": null,
  "delta": null,
  "criteria_results": [],
  "changes_made": [],
  "timestamp": datetime.utcnow().isoformat() + "Z",
  "notes": "Baseline snapshot before improvement loop"
}))
```

## Step 4: Iteration Loop

Initialize tracking:

```python
iteration = 1
best_score = 0
best_iteration = 0
termination_reason = None
start_time = datetime.utcnow()
```

### Loop body

Repeat until a termination condition is met:

#### 4a. Check termination conditions (before each iteration)

```python
if max_iterations and iteration > max_iterations:
    termination_reason = f"MAX_ITERATIONS ({max_iterations}) reached"
    break

if time_limit and (datetime.utcnow() - start_time) >= time_limit:
    termination_reason = f"TIME ({time_limit}) reached"
    break

if max_evaluations and total_evaluations >= max_evaluations:
    termination_reason = f"MAX_EVALUATIONS ({max_evaluations}) reached"
    break
```

#### 4b. Print iteration header

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [Iteration {N}/{max}]  Target: {agent/skill name}
  Previous score: {prev_score}%  →  Target: {threshold}%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 4c. Run target agent/skill against evaluation target

For subsequent iterations, use `SendMessage` to continue an existing agent rather than spawning a new one (reduces overhead):

```python
if iteration == 1:
    agent_id = Agent(
        prompt=f"Run {improve_target.agent} against {improve_target.evaluation_target}. Follow your SKILL.md at {improve_target.definition_file}.",
        subagent_type="general-purpose"
    )
else:
    SendMessage(
        to=agent_id,
        message=f"Iteration {iteration}: Re-run against {improve_target.evaluation_target} with updated definition at {improve_target.definition_file}."
    )
```

Wait for completion. Note the output path produced by the agent.

#### 4d. Spawn evaluator with rubric and output reference

```python
evaluator_result = Agent(
    prompt=f"""You are the Evaluator skill. Read your SKILL.md at skills/evaluator/SKILL.md.

Rubric:
{score_function_criteria_as_yaml}

Output reference:
  type: directory
  path: {agent_output_path}

Evaluate each criterion. Return the score vector JSON.""",
    skill="evaluator"
)
total_evaluations += 1
```

Parse the score vector JSON from the evaluator's output.

#### 4e. Record iteration result

```python
score_percentage = evaluator_result["score_percentage"]
delta = score_percentage - prev_score if iteration > 1 else 0

Write(f"Claude-Production-Grade-Suite/.orchestrator/iterations/iteration-{iteration}.json", json.dumps({
    "iteration_number": iteration,
    "score_percentage": score_percentage,
    "delta": delta,
    "criteria_results": evaluator_result["score_vector"],
    "changes_made": [],  # filled in step 4f
    "timestamp": datetime.utcnow().isoformat() + "Z"
}))

if score_percentage > best_score:
    best_score = score_percentage
    best_iteration = iteration
```

Print progress:

```
  [Iteration {N}/{max}] Score: {prev_score}% → {score}% (target: {threshold}%)
  Passed: {criteria_passed}/{criteria_total} criteria
```

#### 4f. Check threshold — stop if met

```python
if score_percentage >= threshold:
    termination_reason = f"THRESHOLD ({threshold}%) reached at iteration {iteration}"
    break
```

#### 4g. Modify definition based on feedback (if not stopping)

Read the evaluator's `feedback` for all failed criteria. For each failed criterion:

1. Read the current `definition_file` (SKILL.md or phase file).
2. Identify which section of the definition is responsible for the failure.
3. Propose a targeted modification — be surgical. Change only what the feedback points to.
4. Apply the modification using Edit (the orchestrator uses Edit, not the evaluator).

For modifications that would benefit from a deterministic utility script:
- If the evaluator used LLM fallback (`"method": "llm_fallback"`) for an automatable criterion, create a Python script in `Claude-Production-Grade-Suite/evaluator/scripts/` that handles that check.
- If an existing script produced a false result due to a logic error, fix the script.

Record each change:

```python
changes_made = [
    {"criterion_id": "C2", "change": "Added explicit instruction to resolve all TODO comments before writing output"},
    {"criterion_id": "C2", "change": "Created scripts/check_todos.py for deterministic TODO detection"}
]
# Update iteration record with changes_made
```

Commit the definition changes:

```python
Bash(f"git add {improve_target.definition_file} && git commit -m 'improve: iteration-{iteration} — {brief_change_summary}'")
```

Increment iteration and continue loop.

## Step 5: Completion

When the loop exits, print final summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⬥ IMPROVE — Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Target             {agent/skill name}
  Iterations         {N} completed
  Best score         {best_score}% (iteration {best_iteration})
  Final score        {final_score}%
  Termination        {termination_reason}
  Definition         {definition_file}

  Score progression: {iteration scores as list}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If the best iteration is not the final iteration (score regressed), restore the best-scoring definition:

```python
if best_iteration < iteration:
    Bash(f"git checkout HEAD~{iteration - best_iteration} -- {definition_file}")
    Bash(f"git commit -m 'improve: restore best-scoring definition (iteration {best_iteration}, {best_score}%)'")
    print(f"  ⚠ Score regressed in final iterations — restored definition from iteration {best_iteration}")
```

Write a summary to `Claude-Production-Grade-Suite/.orchestrator/iterations/summary.md`:

```markdown
# Improve Summary — {agent/skill name}

Completed: {timestamp}
Target: {threshold}%
Best score: {best_score}% (iteration {best_iteration})
Termination: {termination_reason}

## Iteration History

| Iteration | Score | Delta | Changes |
|-----------|-------|-------|---------|
| 0 (baseline) | — | — | Initial definition |
| 1 | {score}% | +{delta}% | {change_summary} |
...

## Definition retained

{definition_file} at git commit {commit_hash}
```

## Cron Integration (TIME-based termination)

If the user specified a TIME termination condition of 1 hour or more, create a cron job for persistence across sessions:

```python
CronCreate(
    schedule="*/30 * * * *",  # every 30 minutes
    command=f"Check improve loop status for {improve_target.agent}. Read Claude-Production-Grade-Suite/.orchestrator/iterations/ for current state. If TIME not yet elapsed and THRESHOLD not yet reached, continue iteration loop from last checkpoint.",
    description=f"Improve loop checkpoint: {improve_target.agent}"
)
```

For TIME < 1 hour: run synchronously within the session, no cron needed.

After TIME-based loop completes, delete the cron job:

```python
CronDelete(id=cron_job_id)
```

## Failure Handling

- If the target agent/skill fails to run: record score as 0 for that iteration, log error, continue loop.
- If the evaluator returns malformed JSON: treat all criteria as failed (score = 0), log error, continue.
- If git commit fails: log the failure, continue loop without committing (best-effort versioning).
- If definition modifications show no improvement after 3 consecutive iterations: log a warning and suggest the user refine the rubric or raise the evaluation target.

## State Management

Write improve loop state to `Claude-Production-Grade-Suite/.orchestrator/improve-state.json`:

```json
{
  "improve_session_id": "<uuid>",
  "target": "<agent/skill name>",
  "definition_file": "<path>",
  "evaluation_target": "<path>",
  "threshold": 90,
  "iteration": 3,
  "best_score": 84.2,
  "best_iteration": 2,
  "total_evaluations": 3,
  "start_time": "<ISO-8601>",
  "termination_conditions": {
    "max_iterations": 5,
    "time_limit": null,
    "max_evaluations": null
  },
  "last_updated": "<ISO-8601>"
}
```

Update after each iteration.

## Common Mistakes (IMPROVE Phase)

| Mistake | Fix |
|---------|-----|
| Improving multiple agents simultaneously | One target per Improve session. Scope to ONE agent, ONE skill, or ONE agent+skill pair. |
| Using the evaluator to modify files | The evaluator is read-only. Only the loop orchestrator modifies definitions. |
| Skipping the baseline commit | Always commit iteration-0 before any modifications — enables rollback. |
| Making broad definition changes after each iteration | Be surgical. Change only what the failed criterion feedback points to. |
| Not restoring best-scoring definition on regression | If score dropped in later iterations, restore the best checkpoint. |
| Invoking full pipeline infrastructure | Improve mode has NO waves, NO pipeline gates, NO task receipts. It is a standalone loop. |
| Using Elicitation during the iteration loop | Elicitation is ONLY at the start (scope and score function). The loop runs autonomously. |
| Forgetting to delete cron job after TIME-based loop | CronDelete when TIME termination fires. |
| Fabricating score improvements | Each score must come from the evaluator's output — never hardcode or estimate. |
