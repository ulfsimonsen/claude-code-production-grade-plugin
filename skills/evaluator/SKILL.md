---
name: evaluator
description: >
  Evaluates agent/skill output against binary rubric criteria. Produces
  score vectors with pass/fail per criterion and weighted overall score.
  Used by Improve mode for scored iteration loops. Extractable as standalone.
effort: high
maxTurns: 3
disallowedTools:
  - Write
  - Edit
---

# Evaluator Skill

## Purpose

Binary rubric-based scoring of agent or skill output. The evaluator receives a rubric (list of binary criteria with optional weights) and an output reference (file paths or directory), checks each criterion independently, and returns a score vector with pass/fail per criterion and a weighted overall score percentage.

The evaluator is READ-ONLY. It never modifies source code, SKILL.md files, or any artifact under evaluation. `disallowedTools: [Write, Edit]` enforces this at the framework level.

## Extractability

This skill has NO hard dependencies on the production-grade pipeline infrastructure. It does not load the 8 shared protocols (UX, visual identity, receipts, tool-efficiency, input-validation, freshness-protocol, boundary-safety, conflict-resolution). It does not require `Claude-Production-Grade-Suite/` to exist. It reads a rubric and an output reference — that is its entire contract.

To extract as standalone: copy `skills/evaluator/SKILL.md` and `Claude-Production-Grade-Suite/evaluator/scripts/` to any new project. No other files required.

## Input Contract

The evaluator expects two inputs passed in the invocation context:

```
rubric:
  - id: C1
    description: "All public functions have docstrings"
    weight: 1.0
  - id: C2
    description: "No TODO comments remain in output files"
    weight: 2.0
  - id: C3
    description: "Test pass rate >= 95%"
    weight: 3.0

output_reference:
  type: directory          # "directory" | "files" | "path"
  path: "services/api/"   # or a list of file paths
```

If no weights are provided, all criteria are weighted equally at 1.0.

If no output reference is provided, evaluate the most recently modified files in the working directory.

## Process

Execute all criterion checks before computing any scores. Run independent criteria in parallel using parallel tool calls.

### For each criterion

1. Determine the check method (see Check Method Selection below).
2. Run the check — use Bash to execute Python utility scripts for deterministic checks, use LLM judgment only when automation is insufficient.
3. Record: `{ "id": "C1", "pass": true|false, "evidence": "...", "method": "script|llm" }`

### Check Method Selection

| Criterion type | Method |
|----------------|--------|
| Regex pattern present/absent | Python script: `scripts/check_regex.py` |
| AST-level analysis (function signatures, class structure) | Python script: `scripts/check_ast.py` |
| Test execution and pass rate | Python script: `scripts/run_tests.py` |
| Lint score / lint rule compliance | Python script: `scripts/check_lint.py` |
| File existence, artifact presence | Bash + Glob |
| Structural completeness (section headers, required fields) | Python script: `scripts/check_structure.py` |
| Semantic judgment (tone, clarity, approach) | LLM evaluation with explicit reasoning |
| Custom domain-specific rule | Python script: `scripts/custom/<rule_name>.py` if exists, else LLM |

**Prefer automation.** If a criterion can be checked deterministically with a script, use the script. Reserve LLM judgment for criteria that genuinely cannot be automated (semantic quality, reasoning quality, ambiguous intent).

## Python Utility Scripts

Utility scripts live in `Claude-Production-Grade-Suite/evaluator/scripts/`. The evaluator uses Bash to run them. Each script accepts standardized arguments and exits 0 for pass, 1 for fail, writing a brief result to stdout.

### Standard interface

```bash
python3 Claude-Production-Grade-Suite/evaluator/scripts/<script>.py \
  --path <output_reference> \
  --criterion "<criterion_description>" \
  [--threshold <value>] \
  [--pattern "<regex>"]
```

### Available scripts (created by Improve mode loop as needed)

| Script | Purpose |
|--------|---------|
| `check_regex.py` | Pattern presence/absence in files |
| `check_ast.py` | AST analysis: docstrings, function signatures, class structure |
| `run_tests.py` | Execute test suite, return pass rate |
| `check_lint.py` | Run linter (flake8, eslint, pylint), return score |
| `check_structure.py` | Verify required sections, headers, fields exist |
| `custom/` | Domain-specific scripts created during iteration |

Scripts are created and modified by the Improve mode loop orchestrator, not by the evaluator itself. The evaluator only reads and runs existing scripts.

If a script for the required check does not exist, fall back to LLM evaluation and note `"method": "llm_fallback"` in the evidence.

## Output: Score Vector

After all criterion checks complete, compute the weighted score:

```
score_percentage = (sum of weight for passing criteria) / (sum of all weights) * 100
```

Produce a score vector as structured output (printed to stdout, not written to disk):

```json
{
  "rubric_id": "<rubric identifier or 'ad-hoc'>",
  "evaluated_at": "<ISO-8601 timestamp>",
  "output_reference": "<path evaluated>",
  "criteria_total": 3,
  "criteria_passed": 2,
  "criteria_failed": 1,
  "score_percentage": 83.3,
  "score_vector": [
    {
      "id": "C1",
      "description": "All public functions have docstrings",
      "weight": 1.0,
      "pass": true,
      "evidence": "Checked 14 public functions via AST analysis — all have docstrings.",
      "method": "script"
    },
    {
      "id": "C2",
      "description": "No TODO comments remain in output files",
      "weight": 2.0,
      "pass": false,
      "evidence": "Found 3 TODO comments in services/api/handlers.py (lines 42, 87, 134).",
      "method": "script"
    },
    {
      "id": "C3",
      "description": "Test pass rate >= 95%",
      "weight": 3.0,
      "pass": true,
      "evidence": "97/100 tests passed (97%). Threshold: 95%.",
      "method": "script"
    }
  ],
  "feedback": [
    {
      "criterion_id": "C2",
      "description": "No TODO comments remain in output files",
      "failure_reason": "3 TODO comments found in services/api/handlers.py at lines 42, 87, 134.",
      "suggestion": "Resolve or remove all TODO comments before considering the output complete."
    }
  ]
}
```

Print the full score vector JSON. Do not write it to disk — the Improve mode orchestrator receives it and decides what to store.

## Progress Output

Print a compact header on start:

```
━━━ Evaluator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Print criterion check progress:

```
  Checking C1: All public functions have docstrings... ✓ pass (script)
  Checking C2: No TODO comments remain...              ✗ fail (script) — 3 found
  Checking C3: Test pass rate >= 95%...                ✓ pass (script) — 97%
```

Print completion summary:

```
✓ Evaluator    2/3 criteria passed    Score: 83.3%    ⏱ Xm Ys
```

## Termination and Error Handling

If a criterion check errors (script not found, syntax error, test runner not available):
- Mark the criterion as `"pass": false` with `"evidence": "check_error: <message>"`
- Continue evaluating all remaining criteria
- Note the error in the feedback object

If the output reference path does not exist:
- Return a score vector with all criteria marked `"pass": false`
- Set `"score_percentage": 0`
- Set error in each evidence field: `"output_reference_not_found: <path>"`

If no rubric is provided:
- Halt with a single message: `"Evaluator requires a rubric. Provide binary criteria before invoking."`
- Do NOT fabricate criteria

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Modifying any evaluated file | Never. disallowedTools: [Write, Edit] is enforced. Read and Bash are the only write-adjacent tools available, and Bash must never be used to write files. |
| Writing the score vector to disk | Print it. The loop orchestrator decides persistence. |
| Using LLM judgment for automatable checks | Script first, LLM fallback only when no script covers the criterion. |
| Fabricating passing evidence for a failed criterion | Every pass must cite specific file locations, line numbers, or test output. |
| Evaluating files outside the output_reference scope | Only evaluate what was specified. Do not expand scope silently. |
| Skipping failed criteria feedback | Every `"pass": false` criterion MUST have a `feedback` entry with a specific failure reason and a concrete suggestion. |
| Inventing criteria not in the rubric | Evaluate only the criteria provided. Do not add implicit quality checks. |

## Execution Checklist

Before marking evaluation complete, verify:

- [ ] Every criterion in the rubric has a result entry in `score_vector`
- [ ] Every `"pass": false` criterion has a corresponding entry in `feedback`
- [ ] `criteria_total` equals the number of criteria in the rubric
- [ ] `criteria_passed + criteria_failed = criteria_total`
- [ ] `score_percentage` is computed from weights, not from raw pass count (unless all weights are equal)
- [ ] Every evidence entry cites specific file paths, line numbers, or command output — no vague statements
- [ ] No files were created, modified, or deleted during evaluation
- [ ] Score vector JSON was printed to stdout, not written to disk
