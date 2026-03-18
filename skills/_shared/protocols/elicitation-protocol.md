# Elicitation Protocol — Structured Input via MCP Elicitation

**Every skill in this plugin MUST follow these rules when collecting user input.** MCP Elicitation replaces open-ended text prompts with structured forms — typed, validated, and consistent.

---

## RULE 1: All User Input via MCP Elicitation

**NEVER output text expecting the user to type a free-form response.** Every user decision point MUST use the MCP Elicitation tool with a structured form — not a question, not a prompt, not "let me know what you think."

Elicitation presents a rendered form the user fills in before execution continues. Fields are typed (string, enum, boolean, integer) and validated before submission.

**WRONG:** Printing "What framework would you like to use?" and waiting.
**RIGHT:** Invoking MCP Elicitation with a single-select enum field listing the viable framework options.

---

## RULE 2: Every Form Includes a Free-Form Escape Hatch

Every Elicitation form MUST include a free-form text field as the user's escape hatch — the equivalent of "Chat about this" in the old AskUserQuestion pattern.

This field must:
- Be the last field in the form
- Have a label such as `"Additional context or instructions (optional)"`
- Be non-required (`required: false`)
- Accept any text the user wants to add

If the user fills in this field, treat its contents as override instructions and incorporate them before proceeding.

---

## RULE 3: Recommended Option Presented First

When a field offers multiple options (enum/single-select), the recommended option MUST appear first in the list and carry a `(Recommended)` suffix in its label.

```yaml
# Example enum ordering
options:
  - "PostgreSQL (Recommended)"
  - "MySQL"
  - "SQLite"
```

Never bury the recommended option in the middle or at the end of the list.

---

## AskUserQuestion → Elicitation Mapping Guide

Use this table when converting existing AskUserQuestion patterns to Elicitation forms.

| AskUserQuestion Pattern | Elicitation Equivalent |
|-------------------------|------------------------|
| 2–4 predefined string options | Single-select enum field |
| "Choose all that apply" | Multi-select array field |
| "Enter a name / path / URL" | String input field with description |
| Numeric threshold or count | Integer field with min/max range |
| Yes / No confirmation | Boolean field |
| "Chat about this" last option | Free-form text field (required: false, always last) |

---

## Common Form Patterns

### Single-Select (enum)

Use when the user must pick exactly one option from a fixed set.

```json
{
  "type": "object",
  "properties": {
    "deployment_target": {
      "type": "string",
      "title": "Deployment Target",
      "description": "Where will this service be deployed?",
      "enum": [
        "AWS (Recommended)",
        "GCP",
        "Azure",
        "Self-hosted"
      ]
    },
    "notes": {
      "type": "string",
      "title": "Additional context or instructions (optional)"
    }
  },
  "required": ["deployment_target"]
}
```

### Multi-Select (array of enums)

Use when the user can select one or more options from a set.

```json
{
  "type": "object",
  "properties": {
    "test_types": {
      "type": "array",
      "title": "Test Types",
      "description": "Which test categories should be generated?",
      "items": {
        "type": "string",
        "enum": ["Unit (Recommended)", "Integration", "E2E", "Contract", "Performance"]
      },
      "uniqueItems": true
    },
    "notes": {
      "type": "string",
      "title": "Additional context or instructions (optional)"
    }
  },
  "required": ["test_types"]
}
```

### Text Input (string)

Use for open-ended string values like names, paths, URLs, or descriptions.

```json
{
  "type": "object",
  "properties": {
    "service_name": {
      "type": "string",
      "title": "Service Name",
      "description": "Name used for the Docker container, CI job, and directory."
    },
    "notes": {
      "type": "string",
      "title": "Additional context or instructions (optional)"
    }
  },
  "required": ["service_name"]
}
```

### Numeric Input with Range (integer)

Use for thresholds, counts, or limits where a valid range is known.

```json
{
  "type": "object",
  "properties": {
    "coverage_threshold": {
      "type": "integer",
      "title": "Minimum Code Coverage (%)",
      "description": "Pipeline fails if coverage drops below this value.",
      "minimum": 0,
      "maximum": 100,
      "default": 80
    },
    "notes": {
      "type": "string",
      "title": "Additional context or instructions (optional)"
    }
  },
  "required": ["coverage_threshold"]
}
```

---

## Auto Mode Behavior

In **Auto mode**, skills make **zero Elicitation calls** — the same as zero AskUserQuestion calls.

Every decision that would trigger an Elicitation form is instead:
1. Auto-resolved using the most common/sensible default
2. Logged to `auto-decisions.md` with the chosen value and reasoning

This mirrors the original Auto mode contract: total autonomy, the user walked away. Never block on input. If uncertain, pick the best default and document it.

**The test for whether to elicit:** In Auto mode, NEVER elicit — resolve and log. In Express mode, would a senior engineer resolve this without asking? If yes, auto-resolve it in Express. Each higher engagement mode widens the circle of what gets surfaced via Elicitation forms.

| Mode | Elicitation Behavior |
|------|----------------------|
| **Auto** | Zero Elicitation calls. Auto-resolve every decision. Log all to `auto-decisions.md`. |
| **Express** | Zero Elicitation calls. Auto-resolve everything — report decisions in output. |
| **Standard** | 1–2 forms per skill, only for subjective or irreversible choices. |
| **Thorough** | Surface all major decisions via Elicitation forms before implementing. |
| **Meticulous** | Surface every decision point. User reviews and approves each step. |
